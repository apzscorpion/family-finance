-- ============================================================================
-- Tear down schema v1 so v2 can be created cleanly.
-- ============================================================================
-- DESTRUCTIVE for public-schema application data. It does NOT touch auth.users.
--
-- Why drop rather than migrate: v1 invite codes were derived client-side by a
-- generator that produced only 32 distinct values, so unrelated users may share
-- a family_id. There is no reliable way, after the fact, to decide which rows
-- belong to which household — so the data is discarded rather than carried
-- forward into the new model.
--
-- v1 shapes are also incompatible with v2 (transactions.member_name/cat_key/
-- transaction_time vs. v2's foreign keys and occurred_at), and
-- `create table if not exists` would silently leave the old columns in place.
-- ============================================================================

drop table if exists public.approvals          cascade;
drop table if exists public.budgets            cascade;
drop table if exists public.transactions       cascade;
drop table if exists public.family_memberships cascade;
drop table if exists public.profiles           cascade;
drop table if exists public.families           cascade;

-- Tables that only ever existed in later ad-hoc scripts, dropped defensively.
drop table if exists public.notes             cascade;
drop table if exists public.cards             cascade;
drop table if exists public.money_sources     cascade;
drop table if exists public.categories        cascade;
drop table if exists public.recurring_charges cascade;

-- v1 helper objects, if any survived.
drop function if exists public.handle_new_user() cascade;
