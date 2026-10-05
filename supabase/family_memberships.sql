-- Run once in the Supabase SQL editor before releasing the fixed client.
-- A person can belong to many groups; a code belongs to exactly one group.

alter table public.families add column if not exists invite_code text;
alter table public.families add column if not exists owner_id uuid references auth.users(id);
create unique index if not exists families_invite_code_key
  on public.families (upper(invite_code)) where invite_code is not null;

create table if not exists public.family_memberships (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member', 'viewer')),
  status text not null default 'active' check (status in ('active', 'disabled')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

alter table public.family_memberships enable row level security;

create policy "Members can view their memberships"
  on public.family_memberships for select
  using (user_id = auth.uid());

create policy "Authenticated users can join a family"
  on public.family_memberships for insert
  with check (user_id = auth.uid());

-- Replace the old one-family profile rule with membership-based access before
-- moving shared transactions, budgets and notes to family_id queries.
