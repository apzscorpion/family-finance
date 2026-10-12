-- ============================================================================
-- Wallet: how much of each money source is cash and how much is in the bank.
-- ============================================================================
-- A source's balance (opening + income − spend) is split by payment method:
-- Cash entries move the cash part, everything else (UPI, bank, card) the bank
-- part. Two things the transactions alone cannot express:
--
--   * opening_cash — how much of the opening balance was held as cash.
--   * wallet_moves — withdrawing bank money to cash, or depositing cash, inside
--                    one source. Not spending or income, so not a transaction.
-- ============================================================================

alter table public.money_sources
  add column if not exists opening_cash numeric(14,2) not null default 0;

create table if not exists public.wallet_moves (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  source_id   uuid not null references public.money_sources(id) on delete cascade,
  amount      numeric(14,2) not null check (amount > 0),
  -- true: bank → cash (withdrawal); false: cash → bank (deposit).
  to_cash     boolean not null,
  note        text,
  created_by  uuid references auth.users(id) on delete set null default auth.uid(),
  occurred_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index if not exists wallet_moves_source_idx
  on public.wallet_moves (source_id);

alter table public.wallet_moves enable row level security;

drop policy if exists wallet_moves_select on public.wallet_moves;
create policy wallet_moves_select on public.wallet_moves
  for select using (public.is_family_member(family_id));

drop policy if exists wallet_moves_insert on public.wallet_moves;
create policy wallet_moves_insert on public.wallet_moves
  for insert with check (
    public.has_family_role(family_id, array['owner','admin','member'])
  );

drop policy if exists wallet_moves_delete on public.wallet_moves;
create policy wallet_moves_delete on public.wallet_moves
  for delete using (
    public.has_family_role(family_id, array['owner','admin','member'])
  );

notify pgrst, 'reload schema';
