-- Voice and video calls between family members.
--
-- A row rings the callee: their open app sees the insert over Realtime and
-- shows the incoming-call screen. The media itself never touches the
-- database: offer/answer/ICE travel over a Realtime broadcast channel named
-- call:<id>, then audio/video flow peer to peer (WebRTC).
--
-- Status: ringing -> accepted -> ended, or ringing -> declined | missed.

create table if not exists public.calls (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  caller uuid not null references auth.users(id) on delete cascade,
  callee uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('audio', 'video')),
  status text not null default 'ringing'
    check (status in ('ringing', 'accepted', 'declined', 'missed', 'ended')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  check (caller <> callee)
);

create index if not exists calls_callee_idx on public.calls (callee, started_at desc);
create index if not exists calls_caller_idx on public.calls (caller, started_at desc);

alter table public.calls enable row level security;

drop policy if exists calls_select on public.calls;
create policy calls_select on public.calls
  for select
  using (
    (auth.uid() = caller or auth.uid() = callee)
    and public.is_family_member(family_id)
  );

-- Only the caller creates the row, and only to an active member of the same
-- family.
drop policy if exists calls_insert on public.calls;
create policy calls_insert on public.calls
  for insert
  with check (
    auth.uid() = caller
    and status = 'ringing'
    and public.is_family_member(family_id)
    and exists (
      select 1 from public.family_memberships m
       where m.family_id = calls.family_id
         and m.user_id = calls.callee
         and m.status = 'active'
    )
  );

drop policy if exists calls_update on public.calls;
create policy calls_update on public.calls
  for update
  using (
    (auth.uid() = caller or auth.uid() = callee)
    and public.is_family_member(family_id)
  )
  with check (
    (auth.uid() = caller or auth.uid() = callee)
    and public.is_family_member(family_id)
  );

-- RLS cannot compare old and new rows: keep who/what/when fixed, and make
-- finished calls final.
create or replace function public.guard_call_update()
returns trigger
language plpgsql
as $$
begin
  if new.family_id <> old.family_id or new.caller <> old.caller
     or new.callee <> old.callee or new.kind <> old.kind
     or new.started_at <> old.started_at then
    raise exception 'only status and ended_at of a call can change' using errcode = '42501';
  end if;
  if old.status in ('declined', 'missed', 'ended') and new.status <> old.status then
    raise exception 'call already finished' using errcode = '42501';
  end if;
  if new.status in ('accepted', 'declined') and new.status <> old.status
     and auth.uid() is distinct from old.callee then
    raise exception 'only the callee can answer or decline' using errcode = '42501';
  end if;
  if new.status in ('declined', 'missed', 'ended') and new.ended_at is null then
    new.ended_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists calls_guard on public.calls;
create trigger calls_guard
  before update on public.calls
  for each row execute function public.guard_call_update();

do $$
begin
  begin
    alter publication supabase_realtime add table public.calls;
  exception when duplicate_object then
    null;
  end;
end;
$$;

notify pgrst, 'reload schema';
