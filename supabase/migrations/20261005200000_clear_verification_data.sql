-- Removes the throwaway accounts and families created while verifying the v2
-- schema end-to-end (isolation, join-by-code, code uniqueness). Application
-- rows cascade from auth.users, so deleting the users is enough; the explicit
-- truncate covers any family whose owner was already gone.
delete from auth.users;
truncate table
  public.approvals, public.notes, public.recurring_charges, public.budgets,
  public.transactions, public.cards, public.categories, public.money_sources,
  public.family_memberships, public.profiles, public.families
restart identity cascade;
