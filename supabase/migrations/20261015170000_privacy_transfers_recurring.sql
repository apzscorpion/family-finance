-- Three changes:
--
-- 1. Hide my money from chosen people. family_memberships.hidden_from lists
--    who may not see my entries, accounts, wallet moves or recurring rules.
--    Owners always see everything. Entries split with someone, and income
--    someone added for me, stay visible to them. Only I change my list.
--
-- 2. Transfers between members. transfer_money() records an expense for
--    the sender and an income for the receiver, linked by transfer_id. The
--    income is someone else's money arriving, so it waits for the
--    receiver's approval like any income added for them.
--
-- 3. Recurring income set up for someone else no longer skips approval:
--    rules remember who created them, and a rule's income for another
--    person posts as pending.

-- ── 1. Hide from chosen people ─────────────────────────────────────────────

alter table public.family_memberships
  add column if not exists hidden_from uuid[] not null default '{}';

-- Whether I may see [p_user]'s money. Security definer: reads memberships,
-- shares and transactions without their own policies (no recursion).
create or replace function public.money_visible(p_family uuid, p_user uuid, p_txn uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select p_user is null
    or p_user = auth.uid()
    or public.has_family_role(p_family, array['owner'])
    or not exists (
      select 1 from public.family_memberships m
      where m.family_id = p_family and m.user_id = p_user
        and auth.uid() = any(m.hidden_from)
    )
    or (p_txn is not null and (
      exists (select 1 from public.transaction_shares s
              where s.transaction_id = p_txn and s.user_id = auth.uid())
      or exists (select 1 from public.transactions t
                 where t.id = p_txn and t.added_by = auth.uid())
    ));
$$;

drop policy if exists transactions_select on public.transactions;
create policy transactions_select on public.transactions
  for select using (
    public.is_family_member(family_id)
    and public.money_visible(family_id, user_id, id)
  );

drop policy if exists money_sources_select on public.money_sources;
create policy money_sources_select on public.money_sources
  for select using (
    public.is_family_member(family_id)
    and public.money_visible(family_id, owner_id, null)
  );

drop policy if exists wallet_moves_select on public.wallet_moves;
create policy wallet_moves_select on public.wallet_moves
  for select using (
    public.is_family_member(family_id)
    and public.money_visible(family_id, created_by, null)
  );

drop policy if exists recurring_charges_select on public.recurring_charges;
create policy recurring_charges_select on public.recurring_charges
  for select using (
    public.is_family_member(family_id)
    and public.money_visible(family_id, owner_user_id, null)
  );

create or replace function public.set_hidden_from(p_family uuid, p_users uuid[])
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  perform set_config('kp.privacy', 'on', true);
  update public.family_memberships
     set hidden_from = coalesce(p_users, '{}')
   where family_id = p_family and user_id = auth.uid();
  perform set_config('kp.privacy', 'off', true);
end;
$$;

grant execute on function public.set_hidden_from(uuid, uuid[]) to authenticated;

-- Admins can edit memberships; only the member edits who they hide from.
create or replace function public.guard_hidden_from()
returns trigger
language plpgsql
as $$
begin
  if new.hidden_from is distinct from old.hidden_from
     and current_setting('kp.privacy', true) is distinct from 'on' then
    raise exception 'only the member changes who they hide their money from'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists family_memberships_hidden_from on public.family_memberships;
create trigger family_memberships_hidden_from
  before update of hidden_from on public.family_memberships
  for each row execute function public.guard_hidden_from();

-- ── 2. Transfers ───────────────────────────────────────────────────────────

alter table public.transactions
  add column if not exists transfer_id uuid;

-- 'transfer' for these, and 'auto_recurring', which post_due_recurring has
-- always written but the check never allowed, so auto-posting failed.
alter table public.transactions drop constraint if exists transactions_origin_check;
alter table public.transactions add constraint transactions_origin_check
  check (origin in ('manual', 'sms', 'notification', 'auto_card', 'import',
                    'auto_recurring', 'transfer'));

create or replace function public.transfer_money(
  p_family uuid,
  p_to     uuid,
  p_amount numeric,
  p_note   text default null,
  p_source uuid default null,
  p_method text default 'UPI'
)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_me   uuid := auth.uid();
  v_tid  uuid := gen_random_uuid();
  v_out  uuid;
  v_in   uuid;
  v_from text;
  v_to   text;
begin
  if v_me is null or not public.has_family_role(p_family, array['owner','admin','member']) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_to = v_me or coalesce(p_amount, 0) <= 0 then
    raise exception 'pick someone else and an amount above zero' using errcode = '22023';
  end if;
  if not exists (select 1 from public.family_memberships
                 where family_id = p_family and user_id = p_to and status = 'active') then
    raise exception 'that person is not in this workspace' using errcode = '42704';
  end if;
  if p_source is not null and not exists (
       select 1 from public.money_sources
       where id = p_source and family_id = p_family and owner_id = v_me) then
    raise exception 'send from one of your own accounts' using errcode = '42501';
  end if;

  insert into public.categories (family_id, key, name, icon, color, kind, sort_order)
  values (p_family, 'transfer_out', 'Sent to family', 'arrow-circle-up', '#839ED7', 'expense', 90),
         (p_family, 'transfer_in', 'From family', 'arrow-circle-down', '#6CD79D', 'income', 91)
  on conflict (family_id, key) do nothing;
  select id into v_out from public.categories where family_id = p_family and key = 'transfer_out';
  select id into v_in  from public.categories where family_id = p_family and key = 'transfer_in';

  select coalesce(full_name, 'Family') into v_from from public.profiles where id = v_me;
  select coalesce(full_name, 'Family') into v_to   from public.profiles where id = p_to;

  insert into public.transactions (family_id, user_id, paid_by, source_id, category_id,
    title, amount, type, method, origin, occurred_at, note, transfer_id)
  values (p_family, v_me, v_me, p_source, v_out,
    'To ' || coalesce(v_to, 'Family'), p_amount, 'expense', coalesce(p_method, 'UPI'),
    'transfer', now(), p_note, v_tid);

  -- The guard trigger makes this pending: it is the receiver's to approve.
  insert into public.transactions (family_id, user_id, paid_by, source_id, category_id,
    title, amount, type, method, origin, occurred_at, note, transfer_id)
  values (p_family, p_to, v_me, null, v_in,
    'From ' || coalesce(v_from, 'Family'), p_amount, 'income', coalesce(p_method, 'UPI'),
    'transfer', now(), p_note, v_tid);

  return v_tid;
end;
$$;

grant execute on function public.transfer_money(uuid, uuid, numeric, text, uuid, text) to authenticated;

-- ── 3. Recurring income for someone else waits for them ────────────────────

alter table public.recurring_charges
  add column if not exists created_by uuid default auth.uid();

CREATE OR REPLACE FUNCTION public.post_due_recurring(p_family uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r        record;
  v_count  int := 0;
  v_next   date;
  v_owner  uuid;
begin
  -- Status is set here, not by the income guard: a rule's owner's own
  -- income posts; income someone else set up for them waits for approval.
  perform set_config('kp.income', 'on', true);
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;

  for r in
    select * from public.recurring_charges
    where family_id = p_family
      and active
      and auto_post
      and next_due <= current_date
      and (last_posted is null or last_posted < next_due)
  loop
    -- The charge's owner, not the member who happened to open the app. Only
    -- rows predating this column fall back to auth.uid().
    v_owner := coalesce(r.owner_user_id, auth.uid());

    insert into public.transactions (
      family_id, user_id, paid_by, source_id, category_id, card_id,
      title, amount, type, method, origin, occurred_at, status, added_by
    )
    values (
      r.family_id, v_owner, v_owner, r.source_id, r.category_id, r.card_id,
      r.title, r.amount, coalesce(r.type, 'expense'),
      case when r.card_id is not null then 'Card' else 'Bank' end,
      'auto_recurring', r.next_due::timestamptz,
      case when coalesce(r.type, 'expense') = 'income'
                and r.created_by is not null
                and r.created_by is distinct from v_owner
           then 'pending' else 'posted' end,
      coalesce(r.created_by, v_owner)
    );

    -- Roll forward from the due date, not from today, so a charge that was
    -- missed for a while catches up one period at a time rather than skipping.
    v_next := case r.cadence
                when 'weekly'  then r.next_due + interval '7 days'
                when 'yearly'  then r.next_due + interval '1 year'
                else                r.next_due + interval '1 month'
              end::date;

    update public.recurring_charges
       set last_posted = r.next_due,
           next_due    = v_next
     where id = r.id;

    v_count := v_count + 1;
  end loop;

  perform set_config('kp.income', 'off', true);
  return v_count;
end;
$function$;

notify pgrst, 'reload schema';
