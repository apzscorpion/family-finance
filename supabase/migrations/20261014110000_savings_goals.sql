-- ============================================================================
-- Family Savings Goals
-- ============================================================================
-- Allows family members to collaboratively save towards targets
-- (e.g., "Umrah 2027", "New Car", "Emergency Fund") with target amounts,
-- deadlines, current saved amounts, and visual progress tracking.
-- ============================================================================

create table if not exists public.savings_goals (
  id             uuid primary key default gen_random_uuid(),
  family_id      uuid not null references public.families(id) on delete cascade,
  created_by     uuid references auth.users(id) on delete set null,
  name           text not null,
  target_amount  numeric(14,2) not null check (target_amount > 0),
  current_amount numeric(14,2) not null default 0 check (current_amount >= 0),
  target_date    date,
  icon           text default 'target',
  color          text default '#9184D9',
  category_id    uuid references public.categories(id) on delete set null,
  status         text not null default 'active' check (status in ('active','completed','archived')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists savings_goals_family_status_idx
  on public.savings_goals (family_id, status);

-- Enable RLS
alter table public.savings_goals enable ROW LEVEL SECURITY;

-- Select policy: any member of the family can view goals
drop policy if exists savings_goals_select on public.savings_goals;
create policy savings_goals_select on public.savings_goals
  for select using (
    exists (
      select 1 from public.family_memberships
       where family_id = savings_goals.family_id
         and user_id = auth.uid()
         and status = 'active'
    )
  );

-- Insert policy: active members can create goals
drop policy if exists savings_goals_insert on public.savings_goals;
create policy savings_goals_insert on public.savings_goals
  for insert with check (
    exists (
      select 1 from public.family_memberships
       where family_id = savings_goals.family_id
         and user_id = auth.uid()
         and status = 'active'
    )
  );

-- Update policy: active members can contribute or edit goals
drop policy if exists savings_goals_update on public.savings_goals;
create policy savings_goals_update on public.savings_goals
  for update using (
    exists (
      select 1 from public.family_memberships
       where family_id = savings_goals.family_id
         and user_id = auth.uid()
         and status = 'active'
    )
  );

-- Delete policy: owner, admin, or creator can delete
drop policy if exists savings_goals_delete on public.savings_goals;
create policy savings_goals_delete on public.savings_goals
  for delete using (
    created_by = auth.uid()
    or exists (
      select 1 from public.family_memberships
       where family_id = savings_goals.family_id
         and user_id = auth.uid()
         and role in ('owner', 'admin')
         and status = 'active'
    )
  );

