-- ============================================================================
-- Renaming yourself and your workspace, and deleting your account.
-- ============================================================================
-- None of these were possible from the app: a display name could only be set
-- at sign-up, a family name only at creation, and there was no way to leave at
-- all.
--
-- Deleting needs SECURITY DEFINER because a client holding an anon key cannot
-- touch auth.users, even its own row.
-- ============================================================================

-- ── Renaming yourself ───────────────────────────────────────────────────────
-- Writes both profiles.full_name and the auth metadata, which is what the app
-- reads straight after sign-up, so the two cannot drift apart.

create or replace function public.rename_me(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := nullif(btrim(p_name), '');
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if v_name is null then
    raise exception 'name cannot be empty' using errcode = '22023';
  end if;
  if length(v_name) > 80 then
    raise exception 'name is too long' using errcode = '22023';
  end if;

  update public.profiles
     set full_name = v_name
   where id = auth.uid();

  update auth.users
     set raw_user_meta_data =
           coalesce(raw_user_meta_data, '{}'::jsonb)
           || jsonb_build_object('full_name', v_name)
   where id = auth.uid();
end;
$$;

revoke all on function public.rename_me(text) from public;
grant execute on function public.rename_me(text) to authenticated;

-- ── Renaming the workspace ──────────────────────────────────────────────────
-- Any member may rename it. The workspace is shared, and restricting this to
-- the owner mostly produces a name nobody can correct once the owner stops
-- using the app.

create or replace function public.rename_family(p_family uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := nullif(btrim(p_name), '');
begin
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;
  if v_name is null then
    raise exception 'name cannot be empty' using errcode = '22023';
  end if;
  if length(v_name) > 80 then
    raise exception 'name is too long' using errcode = '22023';
  end if;

  update public.families
     set name = v_name,
         updated_at = now()
   where id = p_family;
end;
$$;

revoke all on function public.rename_family(uuid, text) from public;
grant execute on function public.rename_family(uuid, text) to authenticated;

-- ── Deleting your account ───────────────────────────────────────────────────
-- What happens to shared records is a real decision, not an implementation
-- detail, so it is spelled out here:
--
--   * Everything the user alone owns goes: their transactions, their shares of
--     anyone else's, their private notes, their preferences, their profile.
--   * A family where they were the only member is deleted outright, which
--     cascades its categories, cards, budgets and notes.
--   * A family with other members survives. Ownership moves to the
--     longest-standing remaining member, otherwise the workspace would be left
--     with an owner_id pointing at a deleted user.
--   * Notes they wrote and shared with the family stay, because other members
--     are relying on them; authorship is cleared instead. Their own private
--     notes are deleted.
--
-- Returns the number of families deleted along the way, so the app can say
-- what happened.

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid              uuid := auth.uid();
  v_family           record;
  v_remaining        uuid;
  v_families_deleted int := 0;
  v_txns_deleted     int := 0;
begin
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
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
