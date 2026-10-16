-- ============================================================================
-- Profile photo and "About" line (like WhatsApp) for each person.
-- ============================================================================
-- Reads and writes need no new profiles policies: profiles_select already
-- lets you read your own row and those of people you share an active family
-- with, and profiles_update lets you update only your own row (any column).
--
-- Photos live in a PUBLIC-READ Storage bucket `avatars` at
-- `<uid>/avatar.jpg`. Public read keeps the app simple (a plain URL, no
-- signed-URL refresh); anyone holding the URL can see the photo, but object
-- paths are random user UUIDs and listing needs the select policy below.
-- Only the owner can upload, replace or delete files in their own folder.
-- ============================================================================

alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists about text,
  add column if not exists avatar_updated_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_about_len;
alter table public.profiles
  add constraint profiles_about_len check (about is null or char_length(about) <= 140);

-- A profile can only point at a photo in its own folder.
alter table public.profiles
  drop constraint if exists profiles_avatar_own_folder;
alter table public.profiles
  add constraint profiles_avatar_own_folder
  check (avatar_path is null or avatar_path like id::text || '/%');

-- 1 MB cap; the app uploads ~512px JPEGs (well under 100 KB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Signed-in users may see avatar objects through the API (needed for upsert;
-- the files are public by URL anyway).
drop policy if exists avatars_select on storage.objects;
create policy avatars_select on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

notify pgrst, 'reload schema';
