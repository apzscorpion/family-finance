-- Owner-controlled built-in AI per member.
--
-- * ai_daily_limit: requests per day for this member; null = the default.
--   Only owners change it.
-- * ai_models: built-in models this member may pick, approved by an owner
--   or admin. Empty = the default order only.
-- The ai-proxy function reads both for the family the request names.

alter table public.family_memberships
  add column if not exists ai_daily_limit int check (ai_daily_limit is null or ai_daily_limit between 0 and 1000),
  add column if not exists ai_models text[] not null default '{}';

create or replace function public.set_member_ai(
  p_family uuid, p_user uuid, p_limit int, p_models text[]
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_role text := public.my_role(p_family);
  v_old  public.family_memberships%rowtype;
begin
  if v_role is null or v_role not in ('owner', 'admin') then
    raise exception 'only an owner or admin can change AI access' using errcode = '42501';
  end if;
  select * into v_old from public.family_memberships
   where family_id = p_family and user_id = p_user;
  if not found then
    raise exception 'that person is not in this workspace' using errcode = '42704';
  end if;
  if p_limit is distinct from v_old.ai_daily_limit and v_role <> 'owner' then
    raise exception 'only an owner can change the daily AI limit' using errcode = '42501';
  end if;
  perform set_config('kp.ai', 'on', true);
  update public.family_memberships
     set ai_daily_limit = p_limit,
         ai_models = coalesce(p_models, '{}')
   where family_id = p_family and user_id = p_user;
  perform set_config('kp.ai', 'off', true);
end;
$$;

grant execute on function public.set_member_ai(uuid, uuid, int, text[]) to authenticated;

-- Admins can edit membership rows directly; AI access only via the function.
create or replace function public.guard_member_ai()
returns trigger
language plpgsql
as $$
begin
  if (new.ai_daily_limit is distinct from old.ai_daily_limit
      or new.ai_models is distinct from old.ai_models)
     and current_setting('kp.ai', true) is distinct from 'on' then
    raise exception 'change AI access with set_member_ai' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists family_memberships_ai on public.family_memberships;
create trigger family_memberships_ai
  before update of ai_daily_limit, ai_models on public.family_memberships
  for each row execute function public.guard_member_ai();

notify pgrst, 'reload schema';
