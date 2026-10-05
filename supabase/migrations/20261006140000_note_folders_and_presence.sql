-- ============================================================================
-- Note folders, and realtime for live collaboration.
-- ============================================================================
-- The Family Notes design has a Folders tab beside Notes, and shows who is
-- currently editing ("Sara is editing…", presence avatars, a live dot on the
-- card). Folders need storage; presence needs the table published to realtime
-- so clients can subscribe to changes as well as broadcast their own cursor.
-- ============================================================================

create table if not exists public.note_folders (
  id         uuid primary key default gen_random_uuid(),
  family_id  uuid not null references public.families(id) on delete cascade,
  name       text not null,
  icon       text not null default 'folder',
  color      text not null default '#9184D9',
  sort_order int not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (family_id, name)
);

alter table public.notes
  add column if not exists folder_id uuid references public.note_folders(id)
    on delete set null;

create index if not exists notes_folder_idx on public.notes (folder_id);

alter table public.note_folders enable row level security;

drop policy if exists note_folders_select on public.note_folders;
create policy note_folders_select on public.note_folders
  for select using (public.is_family_member(family_id));

drop policy if exists note_folders_write on public.note_folders;
create policy note_folders_write on public.note_folders
  for insert with check (
    public.has_family_role(family_id, array['owner','admin','member']));

drop policy if exists note_folders_update on public.note_folders;
create policy note_folders_update on public.note_folders
  for update using (
    public.has_family_role(family_id, array['owner','admin','member']));

drop policy if exists note_folders_delete on public.note_folders;
create policy note_folders_delete on public.note_folders
  for delete using (
    public.has_family_role(family_id, array['owner','admin']));

-- Realtime: notes already carries row changes; folders joins it so a folder
-- created on one device appears on another without a manual refresh.
do $$
declare
  t text;
begin
  foreach t in array array['note_folders']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end;
$$;

-- Row-level changes need the full old row for deletes and updates to be
-- distinguishable client-side.
alter table public.notes replica identity full;
alter table public.note_folders replica identity full;

notify pgrst, 'reload schema';
