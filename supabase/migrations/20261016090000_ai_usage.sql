-- Built-in AI: every signed-in user gets a daily allowance through the
-- ai-proxy Edge Function, which holds the provider key. This counts use.
-- No client access: only the function (service role) reads or writes it.

create table if not exists public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day     date not null default current_date,
  count   int  not null default 0,
  primary key (user_id, day)
);

alter table public.ai_usage enable row level security;

-- Takes one request from [p_user]'s allowance for today. Returns how many
-- are left, or -1 when the allowance is used up.
create or replace function public.ai_use(p_user uuid, p_limit int)
returns int
language plpgsql security definer
set search_path = public
as $$
declare
  v_count int;
begin
  insert into public.ai_usage (user_id, day, count)
  values (p_user, current_date, 1)
  on conflict (user_id, day) do update
    set count = ai_usage.count + 1
    where ai_usage.count < p_limit
  returning count into v_count;
  if v_count is null then
    return -1;
  end if;
  return p_limit - v_count;
end;
$$;

revoke all on function public.ai_use(uuid, int) from public, anon, authenticated;
grant execute on function public.ai_use(uuid, int) to service_role;
