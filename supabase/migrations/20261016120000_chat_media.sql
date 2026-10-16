-- Chat media: photos, files and voice notes in private Storage, plus
-- "view once" photos. Old messages keep their base64 image_data untouched.
--
-- Object path: <family_id>/<low_uuid>_<high_uuid>/<message_id>/<file_name>
-- where low/high are the two participants' ids sorted as text.

-- ── Columns ─────────────────────────────────────────────────────────────────
alter table public.direct_messages
  add column if not exists media_path text,
  add column if not exists media_name text,
  add column if not exists media_mime text,
  add column if not exists media_size bigint,
  add column if not exists media_kind text,
  add column if not exists media_duration_ms integer,
  add column if not exists view_once boolean not null default false,
  add column if not exists viewed_at timestamptz;

alter table public.direct_messages
  drop constraint if exists direct_messages_media_kind_chk,
  add constraint direct_messages_media_kind_chk
    check (media_kind is null or media_kind in ('image', 'file', 'voice'));

-- A row may only point at an object inside its own folder, so a sender cannot
-- claim someone else's file and gain read access through the policy below.
alter table public.direct_messages
  drop constraint if exists direct_messages_media_path_chk,
  add constraint direct_messages_media_path_chk
    check (
      media_path is null
      or starts_with(
        media_path,
        family_id::text || '/'
          || least(sender_id::text, recipient_id::text) || '_'
          || greatest(sender_id::text, recipient_id::text) || '/'
          || id::text || '/'
      )
    );

-- Also the index the storage policies look objects up by.
create unique index if not exists direct_messages_media_path_key
  on public.direct_messages (media_path)
  where media_path is not null;

-- Media fields are fixed once sent, and a view-once message cannot be
-- "un-viewed" by a direct update (recipients may update read_at).
create or replace function public.direct_messages_media_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.media_path is distinct from old.media_path
     or new.media_kind is distinct from old.media_kind
     or new.view_once is distinct from old.view_once
     or (old.viewed_at is not null and new.viewed_at is distinct from old.viewed_at) then
    raise exception 'Chat media fields cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists direct_messages_media_guard on public.direct_messages;
create trigger direct_messages_media_guard
  before update on public.direct_messages
  for each row execute function public.direct_messages_media_guard();

-- ── Bucket ──────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-media', 'chat-media', false, 26214400) -- 25 MB
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit;

-- ── Storage RLS ─────────────────────────────────────────────────────────────
-- Upload: the caller is one of the two ids in the pair folder and an active
-- member of the family folder. The row is inserted after the upload, so this
-- one can only check the path.
drop policy if exists chat_media_insert on storage.objects;
create policy chat_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and array_length(storage.foldername(name), 1) = 3
    and auth.uid()::text = any (string_to_array((storage.foldername(name))[2], '_'))
    and public.is_family_member(((storage.foldername(name))[1])::uuid)
  );

-- Read: only the sender or recipient of the message that owns the object.
-- A view-once object stops being readable the moment it is viewed.
drop policy if exists chat_media_select on storage.objects;
create policy chat_media_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-media'
    and exists (
      select 1
      from public.direct_messages m
      where m.media_path = storage.objects.name
        and auth.uid() in (m.sender_id, m.recipient_id)
        and (not m.view_once or m.viewed_at is null)
    )
  );

-- Delete: either participant, so deleting a message or clearing the chat
-- also removes its file.
drop policy if exists chat_media_delete on storage.objects;
create policy chat_media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and exists (
      select 1
      from public.direct_messages m
      where m.media_path = storage.objects.name
        and auth.uid() in (m.sender_id, m.recipient_id)
    )
  );

-- ── View once ───────────────────────────────────────────────────────────────
-- Recipient only. Marks the message viewed (which the select policy turns
-- into "unreadable") and deletes the object. The app removes the object
-- through the Storage API first; this delete is the server-side backstop.
create or replace function public.mark_viewed_once(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_path text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  update public.direct_messages
     set viewed_at = now()
   where id = p_message_id
     and recipient_id = v_uid
     and view_once
     and viewed_at is null
  returning media_path into v_path;

  if not found then
    return false;
  end if;

  if v_path is not null then
    begin
      -- Newer Storage versions refuse direct deletes unless this is set.
      perform set_config('storage.allow_delete_query', 'true', true);
      delete from storage.objects
       where bucket_id = 'chat-media'
         and name = v_path;
    exception when others then
      -- Still unreadable: the select policy hides viewed objects.
      null;
    end;
  end if;

  return true;
end;
$$;

revoke execute on function public.mark_viewed_once(uuid) from public, anon;
grant execute on function public.mark_viewed_once(uuid) to authenticated;
