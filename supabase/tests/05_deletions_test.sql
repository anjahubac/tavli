-- Brisanje ostavlja trag, obrisano se ne vraća, kaskade šire tragove,
-- poslednja izmena pobeđuje (FR-016, FR-017).
begin;
select plan(16);

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset

select tests.authenticate_as(:'ua');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('r1', :'ha', 'Sarma', 4, 'manual', '[]', '[]');
insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind)
  values ('v1', :'ha', 'r1', '{}', 'ai');
insert into public.ratings (id, recipe_id, stars, cooked_at) values ('g1', 'r1', 5, now());
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types)
  values ('p1', :'ha', now(), now(), '[]');
insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type, recipe_id)
  values ('e1', :'ha', 'p1', now(), 'lunch', 'r1');

select updated_at as entry_before from public.meal_plan_entries where id = 'e1' \gset

-- Poslednja izmena pobeđuje, updated_at raste.
select updated_at as t1 from public.recipes where id = 'r1' \gset
update public.recipes set title = 'Prva izmena' where id = 'r1';
update public.recipes set title = 'Druga izmena' where id = 'r1';
select ok((select updated_at from public.recipes where id = 'r1') > :'t1'::timestamptz, 'updated_at raste pri izmeni');
select is((select title from public.recipes where id = 'r1'), 'Druga izmena', 'čuva se poslednja izmena');
select is((select updated_by from public.recipes where id = 'r1'), :'ua'::uuid, 'updated_by je onaj ko je menjao');

-- Upsert sa novijim stanjem takođe pobeđuje.
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('r1', :'ha', 'Treća izmena', 4, 'manual', '[]', '[]')
  on conflict (id) do update set title = excluded.title;
select is((select title from public.recipes where id = 'r1'), 'Treća izmena', 'upsert menja postojeći red');

delete from public.recipes where id = 'r1';

select is(
  array(select entity || ':' || record_id from public.deletions order by entity || ':' || record_id collate "C"),
  array['rating:g1', 'recipe:r1', 'recipe_version:v1'],
  'brisanje recepta ostavlja trag za recept, verzije i ocene'
);
select is((select recipe_id from public.meal_plan_entries where id = 'e1'), null, 'stavka plana gubi recept');
select ok((select updated_at from public.meal_plan_entries where id = 'e1') > :'entry_before'::timestamptz, 'stavka plana dobija noviji updated_at');
select is((select household_id from public.deletions where record_id = 'r1'), :'ha'::uuid, 'trag nosi domaćinstvo');
select is((select user_id from public.deletions where record_id = 'g1'), :'ua'::uuid, 'trag ocene nosi osobu');

-- Kasna izmena sa drugog uređaja ne vraća obrisano.
select lives_ok(
  format($$insert into public.recipes (id, household_id, title, servings, source, ingredients, steps) values ('r1', %L, 'Vaskrsla', 4, 'manual', '[]', '[]') on conflict (id) do update set title = excluded.title$$, :'ha'),
  'upsert obrisanog recepta ne baca grešku'
);
select is((select count(*) from public.recipes where id = 'r1'), 0::bigint, 'obrisan recept se ne vraća');
select lives_ok(
  format($$insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind) values ('v2', %L, 'r1', '{}', 'ai')$$, :'ha'),
  'verzija obrisanog recepta ne baca grešku'
);
select is((select count(*) from public.recipe_versions where id = 'v2'), 0::bigint, 'dete obrisanog roditelja se preskače');
select is(tests.affected($$update public.recipes set title = 'X' where id = 'r1'$$), 0::bigint, 'izmena posle brisanja ne menja ništa');
select tests.clear_auth();

-- Tragove vide samo članovi / vlasnik.
select tests.authenticate_as(:'ub');
select is((select count(*) from public.deletions), 0::bigint, 'B ne vidi tragove od A');
select tests.clear_auth();
select tests.authenticate_as(:'ua');
select is((select count(*) from public.deletions), 3::bigint, 'A vidi svoje tragove');
select tests.clear_auth();

select * from finish();
rollback;
