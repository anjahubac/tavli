begin;
select plan(4);

select is(
  (select count(*) from public.foods where household_id is null),
  167::bigint,
  'the reviewed candidate seed contains 167 shared foods'
);
select is(
  (select count(*) from public.foods where household_id is null and nutrition_source is not null),
  145::bigint,
  'only complete owner-approved USDA nutrition records are seeded'
);
select is(
  (select count(*) from public.foods where household_id is null and source like 'Owner-confirmed manual identity/base-unit review%'),
  167::bigint,
  'each seeded identity carries the owner-confirmed approval provenance'
);
select is(
  (select count(*) from public.food_aliases where household_id is null),
  0::bigint,
  'reference-only legacy rows do not add aliases to the candidate seed'
);

select * from finish();
rollback;
