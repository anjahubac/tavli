-- Oznake recepta (TRELLO-37, specs/019-meal-selection-rules/contracts/
-- recipe-labels-contract.md): za koji obrok je pogodan, težina, vrsta jela i
-- ko ih je postavio. Sve su opcione; null znači nepoznato. Postojeće RLS
-- politike i grant na public.recipes već pokrivaju nove kolone.

-- Obroci: 1–4 poznate vrednosti, bez ponavljanja. CHECK ne sme da ima
-- podupit, pa provera ide kroz nepromenljivu funkciju. Poziva je
-- authenticated pri upisu, pa zadržava pravo izvršavanja.
create or replace function private.recipe_meal_types_valid(types text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select types is null or (
    cardinality(types) between 1 and 4
    and types <@ array['breakfast', 'snack', 'lunch', 'dinner']
    and cardinality(types) = (select count(distinct t) from unnest(types) as t)
  );
$$;

revoke execute on function private.recipe_meal_types_valid(text[]) from public, anon;
grant execute on function private.recipe_meal_types_valid(text[]) to authenticated;

alter table public.recipes
  add column meal_types text[]
    check (private.recipe_meal_types_valid(meal_types)),
  add column weight text check (weight in ('light', 'medium', 'hearty')),
  add column dish_kind text check (dish_kind in
    ('soup', 'cooked', 'baked_fried', 'pasta', 'salad', 'pie_pizza_sandwich',
     'eggs_breakfast', 'cold', 'sweet')),
  add column labels_source text check (labels_source in ('ai', 'user'));

-- Izmena recepta bez izvora oznaka (stari klijent, red za slanje iz
-- verzije pre oznaka, uređaj koji još nije skinuo oznake) ne briše oznake
-- koje već postoje, a AI oznake nikad ne zamenjuju oznake korisnika.
-- Oznake se ne mogu obrisati izmenom; korisnik ih uvek postavlja sa izvorom.
create or replace function private.keep_recipe_labels()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.labels_source is null
     or (old.labels_source = 'user' and new.labels_source <> 'user') then
    new.meal_types := old.meal_types;
    new.weight := old.weight;
    new.dish_kind := old.dish_kind;
    new.labels_source := old.labels_source;
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_recipe_labels() from public, anon, authenticated;

create trigger keep_recipe_labels before update on public.recipes
  for each row execute function private.keep_recipe_labels();
