-- Direct Messages v2: image sharing, poke, delete single message, and clear chat for both sender and receiver
do $$
declare
  r record;
begin
  for r in (
    select conname
    from pg_constraint
    where conrelid = 'public.direct_messages'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%body%'
  ) loop
    execute format('alter table public.direct_messages drop constraint if exists %I', r.conname);
  end loop;
end $$;

alter table public.direct_messages
  add column if not exists kind text not null default 'text',
  add column if not exists image_data text;

drop policy if exists dm_delete on public.direct_messages;
create policy dm_delete on public.direct_messages
  for delete
  using (
    auth.uid() = sender_id or auth.uid() = recipient_id
  );

create or replace function public.delete_direct_message(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.direct_messages
   where id = p_message_id
     and (sender_id = v_uid or recipient_id = v_uid);

  return found;
end;
$$;

grant execute on function public.delete_direct_message(uuid) to authenticated;

create or replace function public.clear_direct_thread(
  p_family_id uuid,
  p_partner_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  with deleted as (
    delete from public.direct_messages
     where family_id = p_family_id
       and (
         (sender_id = v_uid and recipient_id = p_partner_id) or
         (sender_id = p_partner_id and recipient_id = v_uid)
       )
    returning 1
  )
  select count(*) into v_count from deleted;

  return v_count;
end;
$$;

grant execute on function public.clear_direct_thread(uuid, uuid) to authenticated;