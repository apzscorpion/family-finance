-- Balances per person. An account (Salary, Loan) is a family-wide label, but
-- the money in it is each member's own: Sinana's "Salary" balance must not
-- include Asif's salary spending, and a balance Asif sets must not move hers.
--
-- source_openings holds each member's opening balance for an account. A
-- member's balance = their opening + their own entries + their own wallet
-- moves; the family view sums every member. money_sources.opening_* stays
-- for older app versions; its values are seeded as the family owner's.

create table if not exists public.source_openings (
  source_id       uuid not null references public.money_sources(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  family_id       uuid not null references public.families(id) on delete cascade,
  opening_balance numeric(14,2) not null default 0,
  opening_cash    numeric(14,2) not null default 0,
  updated_at      timestamptz not null default now(),
  primary key (source_id, user_id)
);

alter table public.source_openings enable row level security;

drop policy if exists source_openings_select on public.source_openings;
create policy source_openings_select on public.source_openings
  for select using (public.is_family_member(family_id));

-- Only the member sets their own opening balance.
drop policy if exists source_openings_insert on public.source_openings;
create policy source_openings_insert on public.source_openings
  for insert with check (
    user_id = auth.uid()
    and public.has_family_role(family_id, array['owner','admin','member'])
  );

drop policy if exists source_openings_update on public.source_openings;
create policy source_openings_update on public.source_openings
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

insert into public.source_openings (source_id, user_id, family_id, opening_balance, opening_cash)
select s.id, m.user_id, s.family_id, s.opening_balance, s.opening_cash
from public.money_sources s
join public.family_memberships m
  on m.family_id = s.family_id and m.role = 'owner' and m.status = 'active'
where s.opening_balance <> 0 or s.opening_cash <> 0
on conflict (source_id, user_id) do nothing;

notify pgrst, 'reload schema';
