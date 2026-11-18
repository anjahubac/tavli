-- Oznake recepta (TRELLO-37, specs/019-meal-selection-rules/contracts/
-- recipe-labels-contract.md): za koji obrok je pogodan, težina, vrsta jela i
-- ko ih je postavio. Sve su opcione; null znači nepoznato. Postojeće RLS
-- politike i grant na public.recipes već pokrivaju nove kolone.
alter table public.recipes
  add column meal_types text[] check (
    meal_types is null or (
      cardinality(meal_types) between 1 and 4
      and meal_types <@ array['breakfast', 'snack', 'lunch', 'dinner'])),
  add column weight text check (weight in ('light', 'medium', 'hearty')),
  add column dish_kind text check (dish_kind in
    ('soup', 'cooked', 'baked_fried', 'pasta', 'salad', 'pie_pizza_sandwich',
     'eggs_breakfast', 'cold', 'sweet')),
  add column labels_source text check (labels_source in ('ai', 'user'));
