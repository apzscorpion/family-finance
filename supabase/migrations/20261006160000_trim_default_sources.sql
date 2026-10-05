-- ============================================================================
-- Seed fewer money sources, and let people manage their own.
-- ============================================================================
-- seed_family_defaults created five sources (Salary, Side business, Rental
-- homes, Loan, Pension & other). Most households only need a couple, and the
-- rest just added noise to the source picker and the Home carousel.
--
-- New workspaces now get Salary and Loan only; anything else is created by the
-- user in Settings.
--
-- Existing workspaces keep whatever they have, except that the three extra
-- seeded names are removed where they are still untouched — no transactions,
-- no opening balance. A source someone has actually used is never deleted.
-- ============================================================================

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

  insert into public.categories (family_id, key, name, icon, color)
  values
    (p_family, 'groceries', 'Groceries', 'basket', '#64C897'),
    (p_family, 'dining', 'Dining', 'fork-knife', '#EE9A69'),
    (p_family, 'transport', 'Transport', 'taxi', '#A297EB'),
    (p_family, 'fuel', 'Fuel', 'gas-pump', '#E2C06D'),
    (p_family, 'shopping', 'Shopping', 'shopping-bag', '#DE82B7'),
    (p_family, 'bills', 'Bills', 'lightning', '#67B5E1'),
    (p_family, 'home', 'Rent', 'house-line', '#839ED7'),
    (p_family, 'subs', 'Subscriptions', 'play-circle', '#BC8FDD'),
    (p_family, 'health', 'Health', 'first-aid', '#EB8186'),
    (p_family, 'education', 'Education', 'graduation-cap', '#6BCAC9'),
    (p_family, 'salary', 'Salary', 'briefcase', '#6CD79D'),
    (p_family, 'business', 'Business', 'storefront', '#6CD79D'),
    (p_family, 'rentin', 'Rental income', 'buildings', '#6CD79D'),
    (p_family, 'loan', 'Loan received', 'hand-coins', '#6CD79D'),
    (p_family, 'pension', 'Pension', 'bank', '#6CD79D'),
    (p_family, 'gift', 'Gift', 'gift', '#6CD79D'),
    (p_family, 'refund', 'Refund', 'arrow-counter-clockwise', '#6CD79D')
  on conflict (family_id, key) do nothing;
end;
$$;

revoke all on function public.seed_family_defaults(uuid) from public;
grant execute on function public.seed_family_defaults(uuid) to authenticated;

-- Remove the extra seeded sources only where they were never used.
delete from public.money_sources ms
where ms.name in ('Side business', 'Rental homes', 'Pension & other')
  and coalesce(ms.opening_balance, 0) = 0
  and not exists (
    select 1 from public.transactions t where t.source_id = ms.id
  )
  and not exists (
    select 1 from public.recurring_charges r where r.source_id = ms.id
  );
