-- ============================================================================
-- Fix: a user could not create a family.
-- ============================================================================
-- families_select required active membership of the family. Creating a family
-- therefore deadlocked: the INSERT succeeded, but PostgREST's
-- `Prefer: return=representation` needs SELECT on the new row, and no
-- membership could exist yet — the caller needs the family's id to create one,
-- and could not read it. The insert came back 403.
--
-- Two changes:
--   1. Owners can always see their own families, membership row or not.
--   2. create_family() makes the family and the owner's membership in one
--      transaction, so the pair can never be half-created.
-- ============================================================================

-- 1. An owner can always see what they own.
drop policy if exists families_select on public.families;
create policy families_select on public.families
  for select using (
    public.is_family_member(id)
    or owner_id = auth.uid()
  );

-- 2. Atomic creation.
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

  insert into public.family_memberships (family_id, user_id, role, status)
  values (v_family.id, auth.uid(), 'owner', 'active');

  return v_family;
end;
$$;

revoke all on function public.create_family(text, text) from public;
grant execute on function public.create_family(text, text) to authenticated;

-- join_family_by_code returned only the id, which left the client unable to
-- show the family it had just joined. Return the row instead.
-- `create or replace` cannot change a return type, so the old one is dropped.
drop function if exists public.join_family_by_code(text);
create or replace function public.join_family_by_code(p_code text)
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

  select * into v_family
  from public.families
  where upper(invite_code) = upper(trim(p_code));

  if v_family.id is null then
    raise exception 'invalid invite code' using errcode = 'no_data_found';
  end if;

  insert into public.family_memberships (family_id, user_id, role, status)
  values (v_family.id, auth.uid(), 'member', 'active')
  on conflict (family_id, user_id) do update set status = 'active';

  return v_family;
end;
$$;

revoke all on function public.join_family_by_code(text) from public;
grant execute on function public.join_family_by_code(text) to authenticated;
