-- In-app "Developer support": bug reports and feature requests land here
-- instead of a GitHub issue, so nobody needs a GitHub account. The developer
-- reads and triages them in the Supabase dashboard (Table Editor →
-- support_requests), which bypasses RLS.
create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid default auth.uid() references auth.users (id) on delete set null,
  email text,
  message text not null check (char_length(message) between 1 and 5000),
  -- Optional screenshot as base64, same approach as direct_messages.image_data.
  screenshot text check (screenshot is null or char_length(screenshot) <= 2000000),
  error_log text check (error_log is null or char_length(error_log) <= 50000),
  app_version text,
  platform text,
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'done', 'wont_fix')),
  created_at timestamptz not null default now()
);

create index if not exists support_requests_status_created_idx
  on public.support_requests (status, created_at desc);

alter table public.support_requests enable row level security;

-- Signed-in users can file requests as themselves and see their own.
drop policy if exists support_insert on public.support_requests;
create policy support_insert on public.support_requests
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'open');

drop policy if exists support_select_own on public.support_requests;
create policy support_select_own on public.support_requests
  for select to authenticated
  using (user_id = auth.uid());
