-- Phase 2 & Phase 3: Live Notes versioning + Direct Messages
alter table public.notes
  add column if not exists version integer not null default 1;

create or replace function public.save_note_v2(
  p_family_id uuid,
  p_id uuid default null,
  p_title text default '',
  p_content text default '',
  p_blocks jsonb default '[]'::jsonb,
  p_pinned boolean default false,
  p_visibility text default 'family',
  p_folder_id uuid default null,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.notes;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_id is null then
    insert into public.notes (
      family_id, title, content, blocks, pinned, visibility, folder_id, created_by, updated_by, version
    ) values (
      p_family_id, p_title, p_content, p_blocks, coalesce(p_pinned, false), coalesce(p_visibility, 'family'), p_folder_id, v_uid, v_uid, 1
    )
    returning * into v_row;

    return jsonb_build_object('ok', true, 'saved', true, 'version', v_row.version, 'row', to_jsonb(v_row));
  end if;

  update public.notes n
     set title = p_title,
         content = p_content,
         blocks = p_blocks,
         pinned = coalesce(p_pinned, n.pinned),
         visibility = coalesce(p_visibility, n.visibility),
         folder_id = p_folder_id,
         updated_by = v_uid,
         updated_at = now(),
         version = n.version + 1
   where n.id = p_id
     and n.family_id = p_family_id
     and (p_expected_version is null or n.version = p_expected_version)
  returning * into v_row;

  if found then
    return jsonb_build_object('ok', true, 'saved', true, 'version', v_row.version, 'row', to_jsonb(v_row));
  end if;

  select * into v_row from public.notes where id = p_id and family_id = p_family_id;
  if not found then
    raise exception 'Note not found';
  end if;

  return jsonb_build_object('ok', false, 'saved', false, 'version', v_row.version, 'row', to_jsonb(v_row));
end;
$$;

grant execute on function public.save_note_v2(uuid, uuid, text, text, jsonb, boolean, text, uuid, integer) to authenticated;

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);