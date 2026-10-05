-- ============================================================================
-- Structured note content.
-- ============================================================================
-- The Family Notes design is a block editor: headings, paragraphs, checklists
-- and tables, each editable in place. A single `content` text column cannot
-- represent that, so blocks are stored as JSON.
--
-- `content` is kept as a flattened plain-text mirror so the list view can show
-- a preview and search can match note bodies without parsing JSON per row.
-- ============================================================================

alter table public.notes
  add column if not exists blocks jsonb not null default '[]'::jsonb,
  add column if not exists color  text,
  add column if not exists visibility text not null default 'family'
    check (visibility in ('family', 'private'));

-- Private notes are visible only to their author; family notes follow the
-- existing membership rule. Replaces the blanket select policy for this table.
drop policy if exists notes_select on public.notes;
create policy notes_select on public.notes
  for select using (
    public.is_family_member(family_id)
    and (visibility = 'family' or created_by = auth.uid())
  );

notify pgrst, 'reload schema';
