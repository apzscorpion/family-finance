-- Sub-categories shared across main categories, people linked to categories,
-- and a transaction's sub-category stored next to its main category.
--
-- A sub-category keeps parent_id (its owner: kind and cascade come from it)
-- and may also be listed under other main categories via also_parent_ids,
-- e.g. "with fam" under Food, Travel and Games.
--
-- member_ids (main or sub): picking the category in the add sheet fills
-- "For" with these people, and picking exactly these people selects it.
--
-- transactions.sub_category_id: with a sub that sits under several mains,
-- category_id alone cannot say which main was meant, so new entries store
-- the main in category_id and the sub here. Older entries that put a sub
-- in category_id are read as (parent, sub) by the app; no data is rewritten.

alter table public.categories
  add column if not exists also_parent_ids uuid[] not null default '{}',
  add column if not exists member_ids uuid[] not null default '{}';

alter table public.transactions
  add column if not exists sub_category_id uuid
    references public.categories(id) on delete set null;

create index if not exists transactions_sub_category_idx
  on public.transactions(sub_category_id)
  where sub_category_id is not null;
