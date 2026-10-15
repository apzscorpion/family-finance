-- Income added for someone else waits for their approval.
--
-- A member may add an expense for anyone, straight away. Income is money in
-- a person's own account, so when A adds income for B (or edits B's income,
-- or moves an income onto B) it is 'pending' until B approves it. B can
-- reject it ('rejected'); it is kept, A can send it again, and B can still
-- approve it later. Only 'posted' entries count in any balance.
--
-- * status: posted | pending | rejected. Set by the trigger, never trusted
--   from the client.
-- * added_by: who entered it (defaults to the signed-in user).
-- * decide_income(txn, approve): only the person the income is for.
-- * resend_income(txn): only who added it; rejected -> pending.

alter table public.transactions
  add column if not exists status text not null default 'posted'
    check (status in ('posted', 'pending', 'rejected')),
  add column if not exists added_by uuid default auth.uid();

create index if not exists transactions_pending_idx
  on public.transactions (user_id) where status <> 'posted';

create or replace function public.guard_income_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The decide/resend functions set this to change status on purpose.
  if current_setting('kp.income', true) = 'on' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.added_by := coalesce(auth.uid(), new.added_by);
    new.status := case
      when new.type = 'income' and auth.uid() is not null
           and new.user_id is distinct from auth.uid() then 'pending'
      else 'posted' end;
    return new;
  end if;

  -- UPDATE: status itself only changes through the functions above.
  new.status := old.status;
  if new.type = 'income' and auth.uid() is not null
     and new.user_id is distinct from auth.uid()
     and (new.user_id is distinct from old.user_id
          or new.type is distinct from old.type
          or new.amount is distinct from old.amount) then
    new.status := 'pending';
    new.added_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_income_status on public.transactions;
create trigger transactions_income_status
  before insert or update on public.transactions
  for each row execute function public.guard_income_status();

create or replace function public.decide_income(p_txn uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('kp.income', 'on', true);
  update public.transactions
     set status = case when p_approve then 'posted' else 'rejected' end
   where id = p_txn
     and user_id = auth.uid()
     and status in ('pending', 'rejected');
  if not found then
    raise exception 'only the person this income is for can decide it'
      using errcode = '42501';
  end if;
  perform set_config('kp.income', 'off', true);
end;
$$;

create or replace function public.resend_income(p_txn uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('kp.income', 'on', true);
  update public.transactions
     set status = 'pending'
   where id = p_txn
     and added_by = auth.uid()
     and status = 'rejected';
  if not found then
    raise exception 'only who added this income can send it again'
      using errcode = '42501';
  end if;
  perform set_config('kp.income', 'off', true);
end;
$$;

grant execute on function public.decide_income(uuid, boolean) to authenticated;
grant execute on function public.resend_income(uuid) to authenticated;

-- Recurring rules post for their owner, whoever's app runs them.
CREATE OR REPLACE FUNCTION public.post_due_recurring(p_family uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r        record;
  v_count  int := 0;
  v_next   date;
  v_owner  uuid;
begin
  -- A rule's owner set it up; their recurring income needs no approval.
  perform set_config('kp.income', 'on', true);
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

  perform set_config('kp.income', 'off', true);
  return v_count;
end;
$function$;

notify pgrst, 'reload schema';
