begin;
select plan(9);

insert into public.households (id, name) values ('00000000-0000-4000-8000-0000000000a1', 'a');

insert into public.foods (id, slug, name, category, base_unit) values
  ('00000000-0000-4000-8000-000000000031', 'unknown-food', 'nepoznato', 'ostalo', 'gram');
select is((select allergen_codes from public.foods where slug = 'unknown-food'), null,
  'a new food has unknown allergens (null), never safe');

select lives_ok($$update public.foods set allergen_codes = array['milk', 'eggs'],
  allergen_source = 'EU 1169/2011 Annex II', allergen_source_ref = 'milk, eggs',
  allergen_reviewed_at = now() where slug = 'unknown-food'$$, 'shared food accepts a reviewed review');
select lives_ok($$update public.foods set allergen_codes = '{}' where slug = 'unknown-food'$$,
  'an empty array is reviewed absence');
select throws_ok($$update public.foods set allergen_codes = array['milk', 'milk'] where slug = 'unknown-food'$$,
  '23514', null, 'rejects duplicate groups');
select throws_ok($$update public.foods set allergen_codes = array['kikiriki'] where slug = 'unknown-food'$$,
  '23514', null, 'rejects unknown group codes');
select throws_ok($$update public.foods set allergen_source = null where slug = 'unknown-food'$$,
  '23514', null, 'a review without a source is rejected');
select throws_ok($$update public.foods set allergen_codes = null where slug = 'unknown-food'$$,
  '23514', null, 'a source without codes is rejected');
select throws_ok($$insert into public.foods (id, household_id, slug, name, category, base_unit, allergen_codes,
  allergen_source, allergen_source_ref, allergen_reviewed_at) values
  ('00000000-0000-4000-8000-000000000032', '00000000-0000-4000-8000-0000000000a1', 'kuci', 'kuci', 'ostalo', 'gram',
  '{}', 's', 'r', now())$$, '23514', null, 'household foods cannot carry an allergen review');
select throws_ok($$update public.foods set allergen_codes = null, allergen_source = null,
  allergen_source_ref = 'x', allergen_reviewed_at = null where slug = 'unknown-food'$$,
  '23514', null, 'partial review fields are rejected');

select * from finish();
rollback;
