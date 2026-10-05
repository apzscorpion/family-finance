-- ============================================================================
-- Who paid, and who owes what.
-- ============================================================================
-- The split was a jsonb blob — `{with: [...], type: 'equal'}` — which can only
-- express "shared equally between these people". It cannot express the cases
-- that matter most:
--
--   * Manu pays ₹1,000 entirely for Remya      → Manu's share 0, Remya's 1000
--   * Manu pays ₹1,000 for C, D and E          → three beneficiaries, payer 0
--   * Manu and Remya share a ₹1,000 dinner     → 500 each
--
-- Shares therefore become rows, and the payer becomes explicit. That also makes
-- "what is the balance between these two people" a plain SQL question instead
-- of something the client has to infer from JSON.
-- ============================================================================

alter table public.transactions
  add column if not exists paid_by uuid references auth.users(id) on delete set null;

-- Existing rows: whoever the entry belonged to is the payer.
update public.transactions set paid_by = user_id where paid_by is null;

create table if not exists public.transaction_shares (
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  user_id        uuid not null references auth.users(id) on delete cascade,
  amount         numeric(14,2) not null check (amount >= 0),
  primary key (transaction_id, user_id)
);

create index if not exists transaction_shares_user_idx
  on public.transaction_shares (user_id);

alter table public.transaction_shares enable row level security;

-- Shares inherit the visibility of their transaction: you can see a share if
-- you are a member of the family that transaction belongs to.
drop policy if exists transaction_shares_select on public.transaction_shares;
create policy transaction_shares_select on public.transaction_shares
  for select using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id and public.is_family_member(t.family_id)
    )
  );

drop policy if exists transaction_shares_write on public.transaction_shares;
create policy transaction_shares_write on public.transaction_shares
  for insert with check (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id
        and public.has_family_role(t.family_id, array['owner','admin','member'])
    )
  );

drop policy if exists transaction_shares_update on public.transaction_shares;
create policy transaction_shares_update on public.transaction_shares
  for update using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id
        and public.has_family_role(t.family_id, array['owner','admin','member'])
    )
  );

drop policy if exists transaction_shares_delete on public.transaction_shares;
create policy transaction_shares_delete on public.transaction_shares
  for delete using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id
        and public.has_family_role(t.family_id, array['owner','admin','member'])
    )
  );

-- ── Pairwise balance ────────────────────────────────────────────────────────
-- Positive  → p_other owes the caller.
-- Negative  → the caller owes p_other.
--
-- Expenses only: income is not something one person owes another. Settlements
-- already recorded as paid are netted off, so clearing a debt zeroes it out.

create or replace function public.pair_balance(p_family uuid, p_other uuid)
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  with me as (select auth.uid() as uid)
  select
    coalesce((
      -- they owe me: I paid, their share
      select sum(s.amount)
      from public.transaction_shares s
      join public.transactions t on t.id = s.transaction_id
      where t.family_id = p_family
        and t.type = 'expense'
        and t.paid_by = (select uid from me)
        and s.user_id = p_other
    ), 0)
    -
    coalesce((
      -- I owe them: they paid, my share
      select sum(s.amount)
      from public.transaction_shares s
      join public.transactions t on t.id = s.transaction_id
      where t.family_id = p_family
        and t.type = 'expense'
        and t.paid_by = p_other
        and s.user_id = (select uid from me)
    ), 0)
    -
    coalesce((
      -- settlements they already paid me reduce what they owe
      select sum(st.amount)
      from public.settlements st
      where st.family_id = p_family
        and st.status = 'settled'
        and st.from_user = p_other
        and st.to_user = (select uid from me)
    ), 0)
    +
    coalesce((
      select sum(st.amount)
      from public.settlements st
      where st.family_id = p_family
        and st.status = 'settled'
        and st.from_user = (select uid from me)
        and st.to_user = p_other
    ), 0);
$$;

revoke all on function public.pair_balance(uuid, uuid) from public;
grant execute on function public.pair_balance(uuid, uuid) to authenticated;

do $$
begin
  begin
    alter publication supabase_realtime add table public.transaction_shares;
  exception when duplicate_object then
    null;
  end;
end;
$$;

notify pgrst, 'reload schema';
