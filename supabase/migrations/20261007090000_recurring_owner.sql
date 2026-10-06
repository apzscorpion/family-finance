-- ============================================================================
-- Recurring charges belong to a person, not to "whoever opened the app".
-- ============================================================================
-- post_due_recurring() inserted the generated transaction with user_id =
-- auth.uid(). auth.uid() is the member who happened to trigger the posting, so
-- a salary set up by one person was credited to whichever family member opened
-- the app that day — and with no owner recorded anywhere, there was nothing to
-- correct it against.
--
-- recurring_charges now records who the charge belongs to, and the posting
-- function attributes the transaction to that person. auth.uid() remains only
-- as a fallback for rows created before this migration that could not be
-- backfilled.
-- ============================================================================

alter table public.recurring_charges
  add column if not exists owner_user_id uuid
    references auth.users(id) on delete set null;

-- Backfill: where a family has exactly one member, the owner is unambiguous.
-- Families with several members are left null and fall back to the old
-- behaviour until the charge is edited, because guessing would silently move
-- somebody's salary onto the wrong person.
update public.recurring_charges rc
   set owner_user_id = m.user_id
  from (
    select family_id, min(user_id::text)::uuid as user_id, count(*) as n
      from public.family_memberships
     where status = 'active'
     group by family_id
  ) m
 where rc.owner_user_id is null
   and rc.family_id = m.family_id
   and m.n = 1;

create index if not exists recurring_charges_owner_idx
  on public.recurring_charges (owner_user_id);

create or replace function public.post_due_recurring(p_family uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r        record;
  v_count  int := 0;
  v_next   date;
  v_owner  uuid;
begin
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;

  for r in
    select * from public.recurring_charges
    where family_id = p_family
      and active
      and auto_post
      and next_due <= current_date
      and (last_posted is null or last_posted < next_due)
  loop
    -- The charge's owner, not the member who happened to open the app. Only
    -- rows predating this column fall back to auth.uid().
    v_owner := coalesce(r.owner_user_id, auth.uid());

    insert into public.transactions (
      family_id, user_id, paid_by, source_id, category_id, card_id,
      title, amount, type, method, origin, occurred_at
    )
    values (
      r.family_id, v_owner, v_owner, r.source_id, r.category_id, r.card_id,
      r.title, r.amount, coalesce(r.type, 'expense'),
      case when r.card_id is not null then 'Card' else 'Bank' end,
      'auto_recurring', r.next_due::timestamptz
    );

    -- Roll forward from the due date, not from today, so a charge that was
    -- missed for a while catches up one period at a time rather than skipping.
    v_next := case r.cadence
                when 'weekly'  then r.next_due + interval '7 days'
                when 'yearly'  then r.next_due + interval '1 year'
                else                r.next_due + interval '1 month'
              end::date;

    update public.recurring_charges
       set last_posted = r.next_due,
           next_due    = v_next
     where id = r.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.post_due_recurring(uuid) from public;
grant execute on function public.post_due_recurring(uuid) to authenticated;

notify pgrst, 'reload schema';
