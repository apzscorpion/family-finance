-- App lock is opt-in: off unless the person turns it on in Settings.
-- Existing rows only ever held the old default, so they are reset once.
alter table public.user_preferences alter column lock_app set default false;
update public.user_preferences set lock_app = false where lock_app;
