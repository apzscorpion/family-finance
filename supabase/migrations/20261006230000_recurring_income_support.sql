-- ============================================================================
-- Support recurring income (e.g. salary credited on 1st of month)
-- ============================================================================

alter table public.recurring_charges
  add column if not exists type text not null default 'expense'
    check (type in ('expense', 'income'));

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
    insert into public.transactions (
      family_id, user_id, paid_by, source_id, category_id, card_id,
      title, amount, type, method, origin, occurred_at
    )
    values (
      r.family_id, auth.uid(), auth.uid(), r.source_id, r.category_id, r.card_id,
      r.title, r.amount, coalesce(r.type, 'expense'),
      case when r.card_id is not null then 'Card' else 'Bank' end,
      'auto_recurring', r.next_due::timestamptz
    );

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
