begin;
select plan(4);

insert into public.foods (id, slug, name, category, base_unit)
values ('00000000-0000-4000-8000-000000000023', 'nutrient-test', 'test', 'ostalo', 'gram');

select throws_ok($$update public.foods set kcal_per_100g = 'Infinity' where id = '00000000-0000-4000-8000-000000000023'$$,
  '23514', null, 'rejects infinite calories');
select throws_ok($$update public.foods set protein_grams_per_100g = 'NaN' where id = '00000000-0000-4000-8000-000000000023'$$,
  '23514', null, 'rejects NaN protein');
select throws_ok($$update public.foods set fat_grams_per_100g = 'Infinity' where id = '00000000-0000-4000-8000-000000000023'$$,
  '23514', null, 'rejects infinite fat');
select throws_ok($$update public.foods set carbs_grams_per_100g = 'NaN' where id = '00000000-0000-4000-8000-000000000023'$$,
  '23514', null, 'rejects NaN carbohydrates');

select * from finish();
rollback;
