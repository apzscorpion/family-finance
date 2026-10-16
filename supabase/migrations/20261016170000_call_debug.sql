-- Step-by-step trace of each call (dial, push, ring, answer, offer/answer,
-- ICE, connection state), so a failed call can be diagnosed from the server.
-- Write-only for users; read with the service role. Rows older than 7 days
-- are dropped on insert.

create table if not exists public.call_debug (
  id bigserial primary key,
  call_id uuid,
  user_id uuid not null default auth.uid(),
  at timestamptz not null default now(),
  event text not null check (char_length(event) <= 60),
  detail text check (detail is null or char_length(detail) <= 500)
);

create index if not exists call_debug_call_idx on public.call_debug (call_id, at);

alter table public.call_debug enable row level security;

drop policy if exists call_debug_insert on public.call_debug;
create policy call_debug_insert on public.call_debug
  for insert to authenticated
  with check (user_id = auth.uid());

create or replace function public.call_debug_prune()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.call_debug where at < now() - interval '7 days';
  return null;
end;
$$;

drop trigger if exists call_debug_prune on public.call_debug;
create trigger call_debug_prune
  after insert on public.call_debug
  for each statement execute function public.call_debug_prune();
