-- ============================================================================
-- Schema additions for the v3 design.
-- ============================================================================
-- v2 covered the core ledger. The v3 screens additionally need:
--   * per-member presentation and limits (relationship label, avatar hue,
--     personal budget, allowance flag) — shown in Who spent, scope chips and
--     the Family tab;
--   * settlements, so "Imran owes you ₹1,000" is real state rather than a
--     derived guess that can never be marked paid;
--   * a detected-payment queue, which the Detected page reviews;
--   * per-user preferences, which Settings writes;
--   * invites carrying a role and a spend-alert limit, which the Invite sheet
--     configures and join-by-code consumes.
-- ============================================================================

-- ── Member presentation and limits ──────────────────────────────────────────

alter table public.family_memberships
  add column if not exists relationship   text,
  add column if not exists avatar_hue     int,
  add column if not exists monthly_budget numeric(14,2),
  add column if not exists is_allowance   boolean not null default false;

-- ── Settlements ─────────────────────────────────────────────────────────────
-- A split leaves someone owing someone else. That debt is a record with a
-- lifecycle, not a number recomputed on every render.
create table if not exists public.settlements (
  id             uuid primary key default gen_random_uuid(),
  family_id      uuid not null references public.families(id) on delete cascade,
  from_user      uuid not null references auth.users(id) on delete cascade,
  to_user        uuid not null references auth.users(id) on delete cascade,
  amount         numeric(14,2) not null check (amount > 0),
  note           text,
  transaction_id uuid references public.transactions(id) on delete set null,
  status         text not null default 'open' check (status in ('open','settled','cancelled')),
  settled_at     timestamptz,
  created_at     timestamptz not null default now(),
  constraint settlements_distinct_parties check (from_user <> to_user)
);

create index if not exists settlements_family_open_idx
  on public.settlements (family_id) where status = 'open';

-- ── Detected payments ───────────────────────────────────────────────────────
-- Parsed from notifications on the device. Raw text stays local; only the
-- fields the user reviews are stored, and only once they choose to keep it.
create table if not exists public.detected_payments (
  id             uuid primary key default gen_random_uuid(),
  family_id      uuid not null references public.families(id) on delete cascade,
  user_id        uuid references auth.users(id) on delete set null,
  source_app     text,
  merchant       text not null,
  amount         numeric(14,2) not null check (amount >= 0),
  method         text,
  category_key   text,
  confidence     text not null default 'high' check (confidence in ('high','check','duplicate')),
  snippet        text,
  note           text,
  status         text not null default 'pending' check (status in ('pending','added','ignored','edited')),
  transaction_id uuid references public.transactions(id) on delete set null,
  detected_at    timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

create index if not exists detected_family_status_idx
  on public.detected_payments (family_id, status, detected_at desc);

-- ── Preferences ─────────────────────────────────────────────────────────────
-- One row per user per family: the same person can watch two households with
-- different alert settings.
create table if not exists public.user_preferences (
  user_id        uuid not null references auth.users(id) on delete cascade,
  family_id      uuid not null references public.families(id) on delete cascade,
  budget_alerts  boolean not null default true,
  family_alerts  boolean not null default true,
  approval_alerts boolean not null default true,
  daily_digest   boolean not null default false,
  sms_auto       boolean not null default true,
  sms_categorize boolean not null default true,
  sms_review     boolean not null default true,
  sms_promo      boolean not null default true,
  lock_app       boolean not null default true,
  hide_on_open   boolean not null default false,
  alert_threshold int not null default 80 check (alert_threshold between 1 and 100),
  chart_style    text not null default 'donut' check (chart_style in ('donut','bars')),
  hero_metric    text not null default 'spent' check (hero_metric in ('spent','balance')),
  updated_at     timestamptz not null default now(),
  primary key (user_id, family_id)
);

drop trigger if exists user_preferences_touch on public.user_preferences;
create trigger user_preferences_touch before update on public.user_preferences
  for each row execute function public.touch_updated_at();

-- ── Invites ─────────────────────────────────────────────────────────────────
-- The Invite sheet picks a role and a spend-alert limit; those must travel with
-- the code rather than being chosen again after the person joins.
create table if not exists public.family_invites (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  code        text not null default public.generate_invite_code(),
  role        text not null default 'member' check (role in ('admin','member','viewer')),
  spend_limit numeric(14,2),
  created_by  uuid references auth.users(id) on delete set null,
  expires_at  timestamptz not null default (now() + interval '7 days'),
  used_count  int not null default 0,
  revoked     boolean not null default false,
  created_at  timestamptz not null default now()
);

create unique index if not exists family_invites_code_key
  on public.family_invites (upper(code));

-- ── RLS ─────────────────────────────────────────────────────────────────────

alter table public.settlements       enable row level security;
alter table public.detected_payments enable row level security;
alter table public.user_preferences  enable row level security;
alter table public.family_invites    enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['settlements','detected_payments','family_invites']
  loop
    execute format('drop policy if exists %I_select on public.%I', t, t);
    execute format(
      'create policy %I_select on public.%I for select using (public.is_family_member(family_id))', t, t);

    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format(
      'create policy %I_write on public.%I for insert with check (public.has_family_role(family_id, array[''owner'',''admin'',''member'']))', t, t);

    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format(
      'create policy %I_update on public.%I for update using (public.has_family_role(family_id, array[''owner'',''admin'',''member'']))', t, t);

    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format(
      'create policy %I_delete on public.%I for delete using (public.has_family_role(family_id, array[''owner'',''admin'']))', t, t);
  end loop;
end;
$$;

-- Preferences are personal: only ever your own row.
drop policy if exists user_preferences_own on public.user_preferences;
create policy user_preferences_own on public.user_preferences
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Joining through a configured invite ─────────────────────────────────────

create or replace function public.redeem_invite(p_code text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.family_invites;
  v_family public.families;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_invite
  from public.family_invites
  where upper(code) = upper(trim(p_code))
    and not revoked
    and expires_at > now();

  if v_invite.id is null then
    -- Fall back to the family's own permanent code.
    return public.join_family_by_code(p_code);
  end if;

  insert into public.family_memberships (family_id, user_id, role, status)
  values (v_invite.family_id, auth.uid(), v_invite.role, 'active')
  on conflict (family_id, user_id) do update set status = 'active';

  update public.family_invites
     set used_count = used_count + 1
   where id = v_invite.id;

  select * into v_family from public.families where id = v_invite.family_id;
  return v_family;
end;
$$;

revoke all on function public.redeem_invite(text) from public;
grant execute on function public.redeem_invite(text) to authenticated;

-- ── Seeding a new workspace ─────────────────────────────────────────────────
-- A brand-new family with no categories or money sources renders an empty app.
-- This gives it the design's defaults in one call.

create or replace function public.seed_family_defaults(p_family uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;

  insert into public.money_sources (family_id, name, kind, sort_order)
  values (p_family, 'Salary', 'income', 1),
         (p_family, 'Side business', 'income', 2),
         (p_family, 'Rental homes', 'income', 3),
         (p_family, 'Loan', 'loan', 4),
         (p_family, 'Pension & other', 'income', 5)
  on conflict (family_id, name) do nothing;

  insert into public.categories (family_id, key, name, icon, color)
  values
    (p_family, 'groceries', 'Groceries', 'basket', '#64C897'),
    (p_family, 'dining', 'Dining', 'fork-knife', '#EE9A69'),
    (p_family, 'transport', 'Transport', 'taxi', '#A297EB'),
    (p_family, 'fuel', 'Fuel', 'gas-pump', '#E2C06D'),
    (p_family, 'shopping', 'Shopping', 'shopping-bag', '#DE82B7'),
    (p_family, 'bills', 'Bills', 'lightning', '#67B5E1'),
    (p_family, 'home', 'Rent', 'house-line', '#839ED7'),
    (p_family, 'subs', 'Subscriptions', 'play-circle', '#BC8FDD'),
    (p_family, 'health', 'Health', 'first-aid', '#EB8186'),
    (p_family, 'education', 'Education', 'graduation-cap', '#6BCAC9'),
    (p_family, 'salary', 'Salary', 'briefcase', '#6CD79D'),
    (p_family, 'business', 'Business', 'storefront', '#6CD79D'),
    (p_family, 'rentin', 'Rental income', 'buildings', '#6CD79D'),
    (p_family, 'loan', 'Loan received', 'hand-coins', '#6CD79D'),
    (p_family, 'pension', 'Pension', 'bank', '#6CD79D'),
    (p_family, 'gift', 'Gift', 'gift', '#6CD79D'),
    (p_family, 'refund', 'Refund', 'arrow-counter-clockwise', '#6CD79D')
  on conflict (family_id, key) do nothing;
end;
$$;

revoke all on function public.seed_family_defaults(uuid) from public;
grant execute on function public.seed_family_defaults(uuid) to authenticated;

-- create_family now seeds, so a new workspace is usable immediately.
create or replace function public.create_family(
  p_name text,
  p_kind text default 'Family'
)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  v_family public.families;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'family name is required' using errcode = '22023';
  end if;

  insert into public.families (name, kind, owner_id)
  values (trim(p_name), coalesce(p_kind, 'Family'), auth.uid())
  returning * into v_family;

  insert into public.family_memberships
    (family_id, user_id, role, status, relationship, avatar_hue)
  values (v_family.id, auth.uid(), 'owner', 'active', 'You', 289);

  perform public.seed_family_defaults(v_family.id);

  return v_family;
end;
$$;

revoke all on function public.create_family(text, text) from public;
grant execute on function public.create_family(text, text) to authenticated;

-- ── Realtime ────────────────────────────────────────────────────────────────

do $$
declare
  t text;
begin
  foreach t in array array['settlements','detected_payments']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
