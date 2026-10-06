-- ============================================================================
-- Changing what people in a workspace are allowed to do.
-- ============================================================================
-- Roles existed on family_memberships from the start but nothing could change
-- them: whoever created the workspace was owner forever and everyone else was
-- a member forever.
--
-- The rules enforced here, rather than in the app, because the app is not the
-- only thing that can call the API:
--
--   * Only an owner or admin may change anyone's role.
--   * Only the owner may hand ownership on, and doing so demotes them to
--     admin — a workspace has exactly one owner at all times.
--   * Nobody may change their own role. Otherwise any member could promote
--     themselves.
--   * An admin may not alter the owner.
-- ============================================================================

create or replace function public.my_role(p_family uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
    from public.family_memberships
   where family_id = p_family
     and user_id = auth.uid()
     and status = 'active'
   limit 1;
$$;

revoke all on function public.my_role(uuid) from public;
grant execute on function public.my_role(uuid) to authenticated;

-- ── Setting someone's role ──────────────────────────────────────────────────

create or replace function public.set_member_role(
  p_family uuid,
  p_user   uuid,
  p_role   text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me      uuid := auth.uid();
  v_my_role text;
  v_target  text;
begin
  if v_me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  if p_role not in ('admin', 'member', 'viewer') then
    raise exception 'use transfer_ownership to make someone the owner'
      using errcode = '22023';
  end if;

  v_my_role := public.my_role(p_family);
  if v_my_role is null or v_my_role not in ('owner', 'admin') then
    raise exception 'only an owner or admin can change roles'
      using errcode = '42501';
  end if;

  if p_user = v_me then
    raise exception 'you cannot change your own role' using errcode = '42501';
  end if;

  select role into v_target
    from public.family_memberships
   where family_id = p_family and user_id = p_user;

  if v_target is null then
    raise exception 'that person is not in this workspace'
      using errcode = '42704';
  end if;

  if v_target = 'owner' then
    raise exception 'the owner''s role is changed by transferring ownership'
      using errcode = '42501';
  end if;

  update public.family_memberships
     set role = p_role
   where family_id = p_family and user_id = p_user;
end;
$$;

revoke all on function public.set_member_role(uuid, uuid, text) from public;
grant execute on function public.set_member_role(uuid, uuid, text) to authenticated;

-- ── Handing the workspace on ────────────────────────────────────────────────

create or replace function public.transfer_ownership(
  p_family uuid,
  p_user   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  if public.my_role(p_family) <> 'owner' then
    raise exception 'only the owner can hand the workspace on'
      using errcode = '42501';
  end if;

  if p_user = v_me then
    return;  -- already the owner; nothing to do
  end if;

  if not exists (
    select 1 from public.family_memberships
     where family_id = p_family and user_id = p_user and status = 'active'
  ) then
    raise exception 'that person is not in this workspace'
      using errcode = '42704';
  end if;

  update public.family_memberships
     set role = 'owner'
   where family_id = p_family and user_id = p_user;

  -- The outgoing owner keeps administrative rights rather than being dropped
  -- to a plain member, which would be a surprising demotion.
  update public.family_memberships
     set role = 'admin'
   where family_id = p_family and user_id = v_me;

  update public.families
     set owner_id = p_user,
         updated_at = now()
   where id = p_family;
end;
$$;

revoke all on function public.transfer_ownership(uuid, uuid) from public;
grant execute on function public.transfer_ownership(uuid, uuid) to authenticated;

-- ── Removing someone ────────────────────────────────────────────────────────
-- Their shared records stay, for the same reason as in delete_my_account: the
-- rest of the family is relying on them.

create or replace function public.remove_member(p_family uuid, p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me      uuid := auth.uid();
  v_my_role text;
  v_target  text;
begin
  v_my_role := public.my_role(p_family);
  if v_my_role is null or v_my_role not in ('owner', 'admin') then
    raise exception 'only an owner or admin can remove people'
      using errcode = '42501';
  end if;

  if p_user = v_me then
    raise exception 'leave the workspace from your own settings instead'
      using errcode = '42501';
  end if;

  select role into v_target
    from public.family_memberships
   where family_id = p_family and user_id = p_user;

  if v_target = 'owner' then
    raise exception 'the owner cannot be removed' using errcode = '42501';
  end if;

  delete from public.family_memberships
   where family_id = p_family and user_id = p_user;
end;
$$;

revoke all on function public.remove_member(uuid, uuid) from public;
grant execute on function public.remove_member(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
