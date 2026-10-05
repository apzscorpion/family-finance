-- ============================================================================
-- Let PostgREST embed a member's profile.
-- ============================================================================
-- family_memberships.user_id and profiles.id both reference auth.users, but
-- there is no foreign key *between* them, so PostgREST refuses the embed:
--
--   PGRST200: Could not find a relationship between 'family_memberships'
--             and 'profiles' in the schema cache
--
-- Every screen that shows who spent what needs the member's name alongside the
-- membership row, so the relationship is made explicit. profiles.id is the
-- primary key and is itself FK'd to auth.users, so this adds a constraint
-- rather than a new source of truth.
-- ============================================================================

-- Any membership whose user has no profile row would block the constraint.
-- handle_new_user() creates one per signup; this backfills anything older.
insert into public.profiles (id, full_name)
select distinct m.user_id, ''
from public.family_memberships m
left join public.profiles p on p.id = m.user_id
where p.id is null
on conflict (id) do nothing;

alter table public.family_memberships
  drop constraint if exists family_memberships_user_profile_fkey;

alter table public.family_memberships
  add constraint family_memberships_user_profile_fkey
  foreign key (user_id) references public.profiles(id) on delete cascade;

notify pgrst, 'reload schema';
