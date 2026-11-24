begin;
select plan(13);

select is(
  (select count(*) from public.foods
   where household_id is null and source like 'Uroš Milutinović confirmed in chat on 2026-11-24%'),
  171::bigint,
  'all 171 owner-approved historical reference foods are seeded'
);
select is(
  (select count(*) from public.foods where household_id is null),
  338::bigint,
  'the shared catalog holds 338 foods'
);
select is(
  (select count(*) from public.foods
   where household_id is null and nutrition_source is not null
     and source like 'Uroš Milutinović confirmed%'),
  166::bigint,
  'only complete owner-approved USDA records carry nutrition'
);
select is(
  (select count(*) from public.food_aliases where household_id is null),
  326::bigint,
  'historical aliases are seeded as shared aliases'
);
select is(
  (select count(*) from public.food_aliases where alias_normalized in ('brašno t-400', 'brašno t-500')),
  0::bigint,
  'disputed flour aliases are omitted'
);
select is(
  (select count(*) from public.food_aliases a
   join public.foods f on lower(f.name) = a.alias_normalized and f.household_id is null
   where a.household_id is null),
  0::bigint,
  'no shared alias repeats a canonical food name'
);
select is(
  (select f.slug from public.food_aliases a join public.foods f on f.id = a.food_id
   where a.alias_normalized = 'krompira'),
  'krompir',
  'an inflected alias resolves to its food'
);
select is(
  (select count(*) from public.foods
   where source like 'Uroš Milutinović confirmed%' and allergen_codes is not null
     and allergen_source_ref like '%(reviewed by Uroš Milutinović)'),
  152::bigint,
  'the 152 reviewed reference foods carry a named allergen review'
);
select is(
  (select count(*) from public.foods
   where source like 'Uroš Milutinović confirmed%' and allergen_codes is null),
  19::bigint,
  'products whose allergens depend on the label stay unknown'
);
select is(
  (select allergen_codes from public.foods where slug = 'losos'),
  array['fish'],
  'salmon is fish'
);
select is(
  (select allergen_codes from public.foods where slug = 'psenicno-brasno'),
  array['gluten'],
  'wheat flour contains gluten'
);
select is(
  (select allergen_codes from public.foods where slug = 'hleb'),
  array['gluten'],
  'bread contains gluten'
);
select ok(
  (select allergen_codes is null from public.foods where slug = 'kobasica'),
  'sausage stays unknown without a product-specific review'
);

select * from finish();
rollback;
