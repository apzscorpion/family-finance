-- Several owners, one primary. families.owner_id is the primary owner (the
-- creator unless handed on). Any number of members can have the 'owner'
-- role, with the owner's full access; admins keep less.
--
-- * Only the primary owner grants or removes the owner role.
-- * Nobody changes the primary owner's role except by transfer_ownership.
-- * transfer_ownership makes someone else primary; the outgoing primary
--   stays an owner.
-- A trigger enforces this on every role change, so a direct table update
-- (the app's fallback path, or an admin's own client) can't skip it.

create or replace function public.guard_owner_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_primary uuid;
begin
  if new.role is not distinct from old.role then
    return new;
  end if;
  select owner_id into v_primary from public.families where id = new.family_id;
  if new.user_id = v_primary and current_setting('kp.transfer', true) is distinct from 'on' then
    raise exception 'the primary owner''s role changes only by transferring ownership'
      using errcode = '42501';
  end if;
  if (new.role = 'owner' or old.role = 'owner')
     and auth.uid() is distinct from v_primary
     and current_setting('kp.transfer', true) is distinct from 'on' then
    raise exception 'only the primary owner can grant or remove the owner role'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists family_memberships_owner_role on public.family_memberships;
create trigger family_memberships_owner_role
  before update of role on public.family_memberships
  for each row execute function public.guard_owner_role();

-- Removing someone: an owner only by the primary owner (or themselves);
-- the primary owner never, until they hand the workspace on.
create or replace function public.guard_owner_removal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_primary uuid;
begin
  if current_setting('kp.transfer', true) = 'on' then
    return old;
  end if;
  select owner_id into v_primary from public.families where id = old.family_id;
  if old.user_id = v_primary and exists (select 1 from public.families where id = old.family_id) then
    raise exception 'transfer ownership before the primary owner leaves'
      using errcode = '42501';
  end if;
  if old.role = 'owner' and auth.uid() is distinct from v_primary
     and auth.uid() is distinct from old.user_id then
    raise exception 'only the primary owner can remove an owner'
      using errcode = '42501';
  end if;
  return old;
end;
$$;

drop trigger if exists family_memberships_owner_removal on public.family_memberships;
create trigger family_memberships_owner_removal
  before delete on public.family_memberships
  for each row execute function public.guard_owner_removal();

create or replace function public.set_member_role(p_family uuid, p_user uuid, p_role text)
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

  if p_role not in ('owner', 'admin', 'member', 'viewer') then
    raise exception 'unknown role' using errcode = '22023';
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

  -- The owner role itself is guarded by guard_owner_role().
  update public.family_memberships
     set role = p_role
   where family_id = p_family and user_id = p_user;
end;
$$;

create or replace function public.transfer_ownership(p_family uuid, p_user uuid)
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

  if not exists (select 1 from public.families where id = p_family and owner_id = v_me) then
    raise exception 'only the primary owner can hand the workspace on'
      using errcode = '42501';
  end if;

  if p_user = v_me then
    return;
  end if;

  if not exists (
    select 1 from public.family_memberships
     where family_id = p_family and user_id = p_user and status = 'active'
  ) then
    raise exception 'that person is not in this workspace'
      using errcode = '42704';
  end if;

  perform set_config('kp.transfer', 'on', true);

  update public.family_memberships
     set role = 'owner'
   where family_id = p_family and user_id = p_user;

  -- The outgoing primary stays an owner.
  update public.family_memberships
     set role = 'owner'
   where family_id = p_family and user_id = v_me;

  update public.families
     set owner_id = p_user,
         updated_at = now()
   where id = p_family;

  perform set_config('kp.transfer', 'off', true);
end;
$$;

-- Deleting an account hands the workspace on itself.
CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid              uuid := auth.uid();
  v_family           record;
  v_remaining        uuid;
  v_families_deleted int := 0;
  v_txns_deleted     int := 0;
begin
  -- Lets the owner guards allow the hand-on below.
  perform set_config('kp.transfer', 'on', true);
  if v_uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  -- Shares of other people's transactions, so no split is left referencing a
  -- user who no longer exists.
  delete from public.transaction_shares where user_id = v_uid;

  -- Their own spending, including anything they paid for on behalf of others.
  with removed as (
    delete from public.transactions
     where user_id = v_uid or paid_by = v_uid
    returning 1
  )
  select count(*) into v_txns_deleted from removed;

  delete from public.settlements
   where from_user = v_uid or to_user = v_uid;

  delete from public.approvals where requested_by = v_uid;

  delete from public.detected_payments where user_id = v_uid;

  -- Private notes are theirs alone; shared ones stay for the family.
  delete from public.notes
   where created_by = v_uid and visibility = 'private';

  update public.notes
     set created_by = null
   where created_by = v_uid;

  update public.notes
     set updated_by = null
   where updated_by = v_uid;

  delete from public.user_preferences where user_id = v_uid;

  -- Each family they belonged to: delete it if they were the last one in it,
  -- otherwise hand it on.
  for v_family in
    select f.id, f.owner_id
      from public.families f
      join public.family_memberships m on m.family_id = f.id
     where m.user_id = v_uid
  loop
    select m.user_id into v_remaining
      from public.family_memberships m
     where m.family_id = v_family.id
       and m.user_id <> v_uid
     order by m.joined_at asc
     limit 1;

    if v_remaining is null then
      delete from public.families where id = v_family.id;
      v_families_deleted := v_families_deleted + 1;
    else
      delete from public.family_memberships
       where family_id = v_family.id and user_id = v_uid;

      if v_family.owner_id = v_uid then
        update public.families
           set owner_id = v_remaining
         where id = v_family.id;

        update public.family_memberships
           set role = 'owner'
         where family_id = v_family.id and user_id = v_remaining;
      end if;
    end if;
  end loop;

  delete from public.profiles where id = v_uid;

  -- Last, because it cascades the sessions this call is authenticated by.
  delete from auth.users where id = v_uid;

  return jsonb_build_object(
    'families_deleted', v_families_deleted,
    'transactions_deleted', v_txns_deleted
  );
end;
$function$;

notify pgrst, 'reload schema';
