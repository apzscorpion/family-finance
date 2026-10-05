-- ============================================================================
-- DESTRUCTIVE — deletes every account in auth.users. NOT REVERSIBLE.
-- ============================================================================
-- Run once, explicitly authorised, as part of the v1 -> v2 reset.
--
-- v1 invite codes collided (the client-side generator produced only 32 distinct
-- codes for any number of users), so accounts may already be cross-linked into
-- households they do not belong to. The public-schema data is dropped by the
-- preceding migrations; this removes the accounts themselves so nothing carries
-- a stale family association forward.
--
-- Everyone, including the project owner, must sign up again after this.
--
-- Identities, sessions, refresh tokens and profiles all cascade from
-- auth.users, so a single delete is sufficient.
-- ============================================================================

delete from auth.users;
