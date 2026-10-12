-- ============================================================================
-- Categories: user-defined order, and expense vs income.
-- ============================================================================
-- The add-entry screen listed categories from a hardcoded list in the app, so
-- custom categories never showed up and nobody could put their most-used ones
-- first. Categories now carry:
--
--   * sort_order — the order people set in Settings; the add screen follows it.
--   * kind       — 'expense' or 'income', so a custom category lands on the
--                  right side of the Expense/Income toggle.
--
-- Subcategories already exist as parent_id; they take their parent's kind.
-- ============================================================================

alter table public.categories
  add column if not exists sort_order int not null default 0,
  add column if not exists kind text not null default 'expense'
    check (kind in ('expense','income'));

update public.categories
set kind = 'income'
where key in ('salary','business','rentin','loan','pension','gift','refund');

-- Existing families keep the order the app used to hardcode.
update public.categories c
set sort_order = coalesce(array_position(array[
  'groceries','dining','transport','fuel','shopping',
  'bills','home','subs','health','education',
  'salary','business','rentin','loan','pension','gift','refund'
], c.key), 100);

create or replace function public.seed_family_defaults(p_family uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_family_member(p_family) then
    raise exception 'not a member of this family' using errcode = '42501';
  end if;

  insert into public.money_sources (family_id, name, kind, sort_order)
  values (p_family, 'Salary', 'income', 1),
         (p_family, 'Loan', 'loan', 2)
  on conflict (family_id, name) do nothing;

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
$$;

revoke all on function public.seed_family_defaults(uuid) from public;
grant execute on function public.seed_family_defaults(uuid) to authenticated;

notify pgrst, 'reload schema';
