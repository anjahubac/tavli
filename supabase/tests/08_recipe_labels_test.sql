-- TRELLO-37: oznake recepta. Član domaćinstva postavlja i čita oznake; drugo
-- domaćinstvo ih ne menja; nepoznata vrednost i prazna lista se odbijaju;
-- postojeći recept bez oznaka ostaje ispravan.
begin;
select * from no_plan();

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('ra', :'ha', 'Pasulj', 4, 'manual', '[]', '[]');

select is((select labels_source from public.recipes where id = 'ra'), null::text, 'postojeći recept nema oznake');

-- A postavlja oznake.
select tests.authenticate_as(:'ua');
select is(
  tests.affected($$update public.recipes set meal_types = array['lunch', 'dinner'], weight = 'hearty', dish_kind = 'cooked', labels_source = 'user' where id = 'ra'$$),
  1::bigint, 'član domaćinstva postavlja oznake');
select is((select meal_types from public.recipes where id = 'ra'), array['lunch', 'dinner'], 'A čita obroke');
select is((select dish_kind from public.recipes where id = 'ra'), 'cooked', 'A čita vrstu jela');

-- Nepoznate vrednosti se odbijaju.
select throws_ok($$update public.recipes set weight = 'ogromno' where id = 'ra'$$, '23514', null, 'nepoznata težina se odbija');
select throws_ok($$update public.recipes set dish_kind = 'roast' where id = 'ra'$$, '23514', null, 'nepoznata vrsta jela se odbija');
select throws_ok($$update public.recipes set meal_types = array['brunch'] where id = 'ra'$$, '23514', null, 'nepoznat obrok se odbija');
select throws_ok($$update public.recipes set meal_types = array[]::text[] where id = 'ra'$$, '23514', null, 'prazna lista obroka se odbija');
select throws_ok($$update public.recipes set labels_source = 'robot' where id = 'ra'$$, '23514', null, 'nepoznat izvor se odbija');

-- B ne menja A-ove oznake.
select tests.authenticate_as(:'ub');
select is(tests.affected($$update public.recipes set weight = 'light' where id = 'ra'$$), 0::bigint, 'B ne menja oznake od A');

select tests.clear_auth();
select is((select weight from public.recipes where id = 'ra'), 'hearty', 'oznake od A su ostale iste');

select * from finish();
rollback;
