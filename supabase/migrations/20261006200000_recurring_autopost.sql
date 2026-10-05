-- ============================================================================
-- Auto-posting recurring charges, and card due reminders.
-- ============================================================================
-- recurring_charges knew when something was next due but nothing ever acted on
-- it: the user had to notice and tap "Mark paid". An EMI or a subscription that
-- leaves the account on its own should post itself.
--
-- auto_post distinguishes the two cases:
--   true  → the money leaves automatically (EMI, standing instruction), so the
--           app posts the transaction on the due date.
--   false → the user pays it manually, so the app only reminds them.
-- ============================================================================

alter table public.recurring_charges
  add column if not exists auto_post   boolean not null default false,
  add column if not exists remind_days int not null default 2
    check (remind_days between 0 and 30),
  add column if not exists last_posted date;

alter table public.cards
  add column if not exists remind_days int not null default 3
    check (remind_days between 0 and 30),
  add column if not exists auto_pay    boolean not null default false;

-- ── Posting due charges ─────────────────────────────────────────────────────
-- Returns how many transactions it created. Idempotent per period: a charge
-- whose last_posted already covers the current due date is skipped, so calling
-- this repeatedly on the same day cannot double-charge.

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
      r.title, r.amount, 'expense',
      case when r.card_id is not null then 'Card' else 'Bank' end,
      'auto_card', r.next_due::timestamptz
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
