-- ============================================================================
-- DESTRUCTIVE — ERASES EVERY ACCOUNT AND EVERY RECORD. NOT REVERSIBLE.
-- ============================================================================
-- This is deliberately NOT in supabase/migrations/. Migrations run
-- automatically on `supabase db push`; this must only ever be run by hand,
-- knowingly, against a project you intend to empty.
--
-- After this runs:
--   * every row in every application table is gone;
--   * every account in auth.users is gone, including the project owner's;
--   * everyone must sign up again from scratch.
--
-- The reason for going this far: invite codes used to collide (the old
-- generator produced only 32 distinct codes), so unrelated users may already
-- share a family. There is no reliable way to tell, after the fact, which rows
-- belong to whom — so the contaminated data is discarded rather than migrated.
--
-- Run the v2 schema migration FIRST, then this.
-- ============================================================================

begin;

-- Application data. Order matters only for readability; the FKs cascade.
truncate table
  public.approvals,
  public.notes,
  public.recurring_charges,
  public.budgets,
  public.transactions,
  public.cards,
  public.categories,
  public.money_sources,
  public.family_memberships,
  public.profiles,
  public.families
restart identity cascade;

-- Accounts. profiles cascades from auth.users, but it is truncated above too
-- so this stays correct whichever order a reader assumes.
delete from auth.users;

commit;

-- Verification — every count below must be 0.
select 'families'           as table_name, count(*) from public.families
union all select 'memberships',  count(*) from public.family_memberships
union all select 'profiles',     count(*) from public.profiles
union all select 'transactions', count(*) from public.transactions
union all select 'notes',        count(*) from public.notes
union all select 'auth.users',   count(*) from auth.users;
