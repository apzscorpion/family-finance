-- ============================================================================
-- Family Spend Tracker — schema v2
-- ============================================================================
-- Replaces the v1 schema. What v1 got wrong, and what this fixes:
--
--  1. Invite codes were derived on the CLIENT from a hash of the user's email.
--     The generator collapsed to 32 distinct codes for any number of users, so
--     unrelated people were dropped into the same family and could read each
--     other's finances. Codes are now generated SERVER-side, uniquely, with a
--     unique index as the backstop. A client can no longer choose or derive one.
--
--  2. profiles.family_id allowed exactly one family per user, while the app
--     pretended people could belong to several. Membership is now many-to-many.
--
--  3. The v1 profiles policy read from profiles inside its own USING clause,
--     which recurses. Membership checks now go through a SECURITY DEFINER
--     helper, which is the supported way to break that cycle.
--
--  4. Several shipped features (shared notes, cards, recurring charges, money
--     sources) had no tables at all and lived only in each device's local
--     storage, so "family sharing" never actually shared them.
--
-- Idempotent: safe to re-run.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ── Helpers ─────────────────────────────────────────────────────────────────

-- Ambiguity-free alphabet (no I/O/0/1) for codes people read aloud and retype.
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
  i int;
begin
  loop
    candidate := '';
    for i in 1..8 loop
      -- gen_random_bytes is cryptographically random; unlike the old LCG every
      -- character is independent of the others.
      candidate := candidate || substr(alphabet, 1 + (get_byte(gen_random_bytes(1), 0) % 32), 1);
    end loop;
    exit when not exists (
      select 1 from public.families where invite_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ── Core tables ─────────────────────────────────────────────────────────────

create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  kind        text not null default 'Family' check (kind in ('Family', 'Friends', 'Event', 'Other')),
  invite_code text not null default public.generate_invite_code(),
  owner_id    uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- The backstop: even if generation were ever wrong again, the database refuses
-- to store two families under one code.
create unique index if not exists families_invite_code_key
  on public.families (upper(invite_code));

create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text not null default '',
  avatar_color text not null default '#9184D9',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.family_memberships (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','admin','member','viewer')),
  status    text not null default 'active' check (status in ('active','disabled')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists family_memberships_user_idx
  on public.family_memberships (user_id) where status = 'active';

-- Money sources: replaces the client-only "savings ways", "loan types" and the
-- account-balance map that previously lived in SharedPreferences.
create table if not exists public.money_sources (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references public.families(id) on delete cascade,
  name            text not null,
  kind            text not null default 'savings' check (kind in ('savings','income','loan','card','cash')),
  opening_balance numeric(14,2) not null default 0,
  sort_order      int not null default 0,
  archived        boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (family_id, name)
);

create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families(id) on delete cascade,
  key        text not null,
  name       text not null,
  icon       text,
  color      text,
  parent_id  uuid references public.categories(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (family_id, key)
);

create table if not exists public.cards (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families(id) on delete cascade,
  label        text not null,
  last4        text check (last4 is null or last4 ~ '^[0-9]{4}$'),
  credit_limit numeric(14,2) not null default 0,
  billing_day  int check (billing_day between 1 and 31),
  due_day      int check (due_day between 1 and 31),
  created_at   timestamptz not null default now()
);

create table if not exists public.transactions (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  user_id     uuid references auth.users(id) on delete set null,
  source_id   uuid references public.money_sources(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,
  card_id     uuid references public.cards(id) on delete set null,
  title       text not null,
  amount      numeric(14,2) not null check (amount >= 0),
  type        text not null check (type in ('expense','income')),
  method      text not null default 'UPI',
  origin      text not null default 'manual' check (origin in ('manual','sms','notification','auto_card','import')),
  -- A real instant, not the v1 client-side "daysAgo" integer that was written
  -- once as 0 and never recomputed, so every transaction stayed "today".
  occurred_at timestamptz not null default now(),
  split       jsonb,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists transactions_family_time_idx
  on public.transactions (family_id, occurred_at desc);
create index if not exists transactions_user_idx
  on public.transactions (user_id);

create table if not exists public.budgets (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families(id) on delete cascade,
  category_id   uuid references public.categories(id) on delete cascade,
  limit_amount  numeric(14,2) not null check (limit_amount >= 0),
  period        text not null default 'monthly' check (period in ('weekly','monthly','yearly')),
  threshold_pct int not null default 80 check (threshold_pct between 1 and 100),
  created_at    timestamptz not null default now(),
  unique (family_id, category_id, period)
);

create table if not exists public.recurring_charges (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  title       text not null,
  amount      numeric(14,2) not null check (amount >= 0),
  cadence     text not null default 'monthly' check (cadence in ('weekly','monthly','yearly')),
  next_due    date not null,
  source_id   uuid references public.money_sources(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,
  card_id     uuid references public.cards(id) on delete set null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Shared notes had no table at all in v1 despite being a headline feature.
create table if not exists public.notes (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families(id) on delete cascade,
  title      text not null default '',
  content    text not null default '',
  pinned     boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notes_family_idx
  on public.notes (family_id, pinned desc, updated_at desc);

create table if not exists public.approvals (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families(id) on delete cascade,
  requested_by uuid references auth.users(id) on delete set null,
  kind         text not null check (kind in ('new','edit','delete','join')),
  reason       text,
  payload      jsonb,
  status       text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by   uuid references auth.users(id) on delete set null,
  decided_at   timestamptz,
  created_at   timestamptz not null default now()
);

-- SECURITY DEFINER so RLS policies can ask "is the caller in this family?"
-- without re-entering the policies on the tables they are protecting.
create or replace function public.is_family_member(p_family uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.family_memberships m
    where m.family_id = p_family
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.has_family_role(p_family uuid, p_roles text[])
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.family_memberships m
    where m.family_id = p_family
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role = any(p_roles)
  );
$$;

-- ── updated_at triggers ─────────────────────────────────────────────────────

drop trigger if exists families_touch on public.families;
create trigger families_touch before update on public.families
  for each row execute function public.touch_updated_at();

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists transactions_touch on public.transactions;
create trigger transactions_touch before update on public.transactions
  for each row execute function public.touch_updated_at();

drop trigger if exists notes_touch on public.notes;
create trigger notes_touch before update on public.notes
  for each row execute function public.touch_updated_at();

-- ── Profile bootstrap ───────────────────────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Row Level Security ──────────────────────────────────────────────────────

alter table public.families          enable row level security;
alter table public.profiles          enable row level security;
alter table public.family_memberships enable row level security;
alter table public.money_sources     enable row level security;
alter table public.categories        enable row level security;
alter table public.cards             enable row level security;
alter table public.transactions      enable row level security;
alter table public.budgets           enable row level security;
alter table public.recurring_charges enable row level security;
alter table public.notes             enable row level security;
alter table public.approvals         enable row level security;

-- families: members read; only owner/admin may rename. Creation is allowed to
-- any authenticated user (they become owner via the membership row).
drop policy if exists families_select on public.families;
create policy families_select on public.families
  for select using (public.is_family_member(id));

drop policy if exists families_insert on public.families;
create policy families_insert on public.families
  for insert with check (auth.uid() is not null and owner_id = auth.uid());

drop policy if exists families_update on public.families;
create policy families_update on public.families
  for update using (public.has_family_role(id, array['owner','admin']));

drop policy if exists families_delete on public.families;
create policy families_delete on public.families
  for delete using (public.has_family_role(id, array['owner']));

-- profiles: you always see your own; you also see those of people you share a
-- family with.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1
      from public.family_memberships mine
      join public.family_memberships theirs on theirs.family_id = mine.family_id
      where mine.user_id = auth.uid()
        and mine.status = 'active'
        and theirs.user_id = public.profiles.id
        and theirs.status = 'active'
    )
  );

drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles
  for insert with check (id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update using (id = auth.uid());

-- memberships: you see rows for families you belong to; you may insert only
-- your own row (joining); owners/admins manage everyone else's.
drop policy if exists memberships_select on public.family_memberships;
create policy memberships_select on public.family_memberships
  for select using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists memberships_insert on public.family_memberships;
create policy memberships_insert on public.family_memberships
  for insert with check (
    user_id = auth.uid()
    or public.has_family_role(family_id, array['owner','admin'])
  );

drop policy if exists memberships_update on public.family_memberships;
create policy memberships_update on public.family_memberships
  for update using (public.has_family_role(family_id, array['owner','admin']));

drop policy if exists memberships_delete on public.family_memberships;
create policy memberships_delete on public.family_memberships
  for delete using (
    user_id = auth.uid()
    or public.has_family_role(family_id, array['owner','admin'])
  );

-- Every family-scoped table shares one rule: active membership of the family.
-- Viewers get read-only; everyone else may write.
do $$
declare
  t text;
begin
  foreach t in array array[
    'money_sources','categories','cards','transactions',
    'budgets','recurring_charges','notes','approvals'
  ]
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format(
      'create policy %I_select on public.%I for select using (public.is_family_member(family_id))',
      t, t
    );

    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format(
      'create policy %I_write on public.%I for insert with check (public.has_family_role(family_id, array[''owner'',''admin'',''member'']))',
      t, t
    );

    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format(
      'create policy %I_update on public.%I for update using (public.has_family_role(family_id, array[''owner'',''admin'',''member'']))',
      t, t
    );

    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format(
      'create policy %I_delete on public.%I for delete using (public.has_family_role(family_id, array[''owner'',''admin'',''member'']))',
      t, t
    );
  end loop;
end;
$$;

-- ── Joining by code ─────────────────────────────────────────────────────────
-- Clients never read the families table by code (that would leak which codes
-- exist). They call this instead, which joins them or fails.

create or replace function public.join_family_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_family uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id into v_family
  from public.families
  where upper(invite_code) = upper(trim(p_code));

  if v_family is null then
    raise exception 'invalid invite code' using errcode = 'no_data_found';
  end if;

  insert into public.family_memberships (family_id, user_id, role, status)
  values (v_family, auth.uid(), 'member', 'active')
  on conflict (family_id, user_id) do update set status = 'active';

  return v_family;
end;
$$;

revoke all on function public.join_family_by_code(text) from public;
grant execute on function public.join_family_by_code(text) to authenticated;

-- ── Realtime ────────────────────────────────────────────────────────────────

do $$
declare
  t text;
begin
  foreach t in array array['transactions','notes','approvals','budgets','family_memberships']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end;
$$;
