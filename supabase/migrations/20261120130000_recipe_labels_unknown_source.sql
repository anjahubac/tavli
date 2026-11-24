-- Oznake recepta: nepoznat izvor oznaka se odbija, a ne tiho zamenjuje.
--
-- Okidač iz 20261118120000_recipe_labels.sql vraćao je stare oznake kad god
-- je stari izvor bio 'user', a novi bilo šta drugo osim 'user'. Okidač radi pre
-- CHECK provere, pa je i nepoznata vrednost (npr. 'robot') bila zamenjena
-- umesto odbijena. Zaštita važi samo za AI oznake preko oznaka korisnika;
-- nepoznata vrednost sada stiže do CHECK provere i odbija se (23514).
create or replace function private.keep_recipe_labels()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.labels_source is null
     or (old.labels_source = 'user' and new.labels_source = 'ai') then
    new.meal_types := old.meal_types;
    new.weight := old.weight;
    new.dish_kind := old.dish_kind;
    new.labels_source := old.labels_source;
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_recipe_labels() from public, anon, authenticated;
