-- Accounts belong to a person. Asif's Salary and Sinana's Business are each
-- one member's money; the family sees them, it doesn't share them.
--
-- * owner_id: whose account it is. Existing accounts go to the family owner
--   (they were all created by them). New accounts default to their creator.
-- * Names are unique per person, so every member can have a "Salary".
-- * Only the account's owner, or the family owner (full admin), can change
--   or delete it, or set its balance.
-- * An entry someone else filed under an owner's account moves to no
--   account, so it counts in its own author's money (their main account).
--   The old source is kept in moved_from_source_id.
-- * member_ids: co-owners of a joint account, with the owner's rights. The
--   app doesn't offer joint accounts yet ("coming soon").

alter table public.money_sources
  add column if not exists owner_id uuid references auth.users(id) on delete cascade
    default auth.uid(),
  add column if not exists member_ids uuid[] not null default '{}';

update public.money_sources s
set owner_id = m.user_id
from public.family_memberships m
where s.owner_id is null
  and m.family_id = s.family_id and m.role = 'owner' and m.status = 'active';

alter table public.money_sources drop constraint if exists money_sources_family_id_name_key;
create unique index if not exists money_sources_owner_name_key
  on public.money_sources (family_id, owner_id, name);

alter table public.transactions
  add column if not exists moved_from_source_id uuid;

update public.transactions t
set moved_from_source_id = t.source_id, source_id = null
from public.money_sources s
where s.id = t.source_id and t.user_id is distinct from s.owner_id;

drop policy if exists money_sources_write on public.money_sources;
create policy money_sources_write on public.money_sources
  for insert with check (
    public.has_family_role(family_id, array['owner','admin','member'])
    and (owner_id = auth.uid() or public.has_family_role(family_id, array['owner']))
  );

drop policy if exists money_sources_update on public.money_sources;
create policy money_sources_update on public.money_sources
  for update using (
    owner_id = auth.uid() or auth.uid() = any(member_ids)
    or public.has_family_role(family_id, array['owner'])
  );

drop policy if exists money_sources_delete on public.money_sources;
create policy money_sources_delete on public.money_sources
  for delete using (
    owner_id = auth.uid() or auth.uid() = any(member_ids)
    or public.has_family_role(family_id, array['owner'])
  );

-- New families: the default accounts are the creator's (owner_id defaults
-- to auth.uid()), unique per person.
CREATE OR REPLACE FUNCTION public.seed_family_defaults(p_family uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;

  insert into public.money_sources (family_id, name, kind, sort_order)
  values (p_family, 'Salary', 'income', 1),
         (p_family, 'Loan', 'loan', 2)
  on conflict (family_id, owner_id, name) do nothing;

  insert into public.categories (family_id, key, name, icon, color, kind, sort_order)
  values
    (p_family, 'groceries', 'Groceries', 'basket', '#64C897', 'expense', 1),
    (p_family, 'dining', 'Dining', 'fork-knife', '#EE9A69', 'expense', 2),
    (p_family, 'transport', 'Transport', 'taxi', '#A297EB', 'expense', 3),
    (p_family, 'fuel', 'Fuel', 'gas-pump', '#E2C06D', 'expense', 4),
    (p_family, 'shopping', 'Shopping', 'shopping-bag', '#DE82B7', 'expense', 5),
    (p_family, 'bills', 'Bills', 'lightning', '#67B5E1', 'expense', 6),
    (p_family, 'home', 'Rent', 'house-line', '#839ED7', 'expense', 7),
    (p_family, 'subs', 'Subscriptions', 'play-circle', '#BC8FDD', 'expense', 8),
    (p_family, 'health', 'Health', 'first-aid', '#EB8186', 'expense', 9),
    (p_family, 'education', 'Education', 'graduation-cap', '#6BCAC9', 'expense', 10),
    (p_family, 'salary', 'Salary', 'briefcase', '#6CD79D', 'income', 11),
    (p_family, 'business', 'Business', 'storefront', '#6CD79D', 'income', 12),
    (p_family, 'rentin', 'Rental income', 'buildings', '#6CD79D', 'income', 13),
    (p_family, 'loan', 'Loan received', 'hand-coins', '#6CD79D', 'income', 14),
    (p_family, 'pension', 'Pension', 'bank', '#6CD79D', 'income', 15),
    (p_family, 'gift', 'Gift', 'gift', '#6CD79D', 'income', 16),
    (p_family, 'refund', 'Refund', 'arrow-counter-clockwise', '#6CD79D', 'income', 17)
  on conflict (family_id, key) do nothing;
end;
$function$;

notify pgrst, 'reload schema';
