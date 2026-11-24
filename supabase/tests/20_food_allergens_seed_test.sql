begin;
select plan(5);

select is((select count(*)::int from public.foods where household_id is null and allergen_codes is not null), 159,
  '159 seeded shared foods have a reviewed allergen status');
select is((select count(*)::int from public.foods where household_id is null and allergen_codes is null), 8,
  'the 8 unresolved foods stay unknown');
select is((select allergen_codes from public.foods where slug = 'kefir'), array['milk'], 'kefir contains milk');
select is((select count(*)::int from public.foods where allergen_codes is not null
  and (allergen_source is null or allergen_source_ref !~ 'reviewed by')), 0, 'every review names its reviewer and source');
select is((select count(*)::int from public.foods where household_id is not null and allergen_codes is not null), 0,
  'household foods never carry reviews');

select * from finish();
rollback;
