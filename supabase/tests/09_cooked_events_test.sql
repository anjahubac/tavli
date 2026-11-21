-- 021: zapis skuvanog obroka i potrošnja iz ostave. Dva naloga (A i B): B ne
-- vidi i ne menja ništa od A; strani ključevi ne dozvoljavaju roditelja iz
-- tuđeg domaćinstva; zapis se samo poništava, a poništavanje se ne vraća;
-- brisanje ostavlja tragove i kaskade.
begin;
select * from no_plan();

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset

-- Podaci oba domaćinstva (kao postgres, bez RLS-a).
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types)
  values ('pa', :'ha', '2026-11-16', '2026-11-22', '["lunch"]'),
         ('pb', :'hb', '2026-11-16', '2026-11-22', '["lunch"]');
insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type, servings, recipe_snapshot)
  values ('ea', :'ha', 'pa', '2026-11-20', 'lunch', 4, '{"title":"Palačinke","servings":4,"ingredients":[]}'),
         ('ea2', :'ha', 'pa', '2026-11-21', 'lunch', 2, '{"title":"Supa","servings":2,"ingredients":[]}'),
         ('eb', :'hb', 'pb', '2026-11-20', 'lunch', 2, '{"title":"Pasulj","servings":2,"ingredients":[]}');
insert into public.pantry_items (id, household_id, name, quantity, unit, category, added_at, confirmed_at)
  values ('oa', :'ha', 'brašno', 1000, 'g', 'suvi proizvodi', now(), now()),
         ('ob', :'hb', 'pasulj', 500, 'g', 'suvi proizvodi', now(), now());
insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at)
  values ('ka', :'ha', 'ea', '2026-11-20', 'lunch', :'ua', 4, now()),
         ('kb', :'hb', 'eb', '2026-11-20', 'lunch', :'ub', 2, now());
insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros)
  values ('ca', :'ha', 'ka', 'oa', 'g', 250000000),
         ('cb', :'hb', 'kb', 'ob', 'g', 200000000);

-- B pokušava da dođe do A-ovih redova.
select tests.authenticate_as(:'ub');
select is((select count(*) from public.cooked_events where household_id = :'ha'), 0::bigint, 'B ne vidi cooked_events od A');
select is(tests.affected($$update public.cooked_events set undone_at = now(), undo_reason = 'user' where id = 'ka'$$), 0::bigint, 'B ne poništava kuvanje od A');
select is(tests.affected($$delete from public.cooked_events where id = 'ka'$$), 0::bigint, 'B ne briše cooked_events od A');
select throws_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('kx', %L, 'ea2', '2026-11-21', 'lunch', %L, 2, now())$$, :'ha', :'ub'), '42501', null, 'B ne dodaje kuvanje u A-ovo domaćinstvo');
select is((select count(*) from public.pantry_consumptions where household_id = :'ha'), 0::bigint, 'B ne vidi pantry_consumptions od A');
select is(tests.affected($$update public.pantry_consumptions set micros = 1 where id = 'ca'$$), 0::bigint, 'B ne menja pantry_consumptions od A');
select is(tests.affected($$delete from public.pantry_consumptions where id = 'ca'$$), 0::bigint, 'B ne briše pantry_consumptions od A');
select throws_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('cx', %L, 'ka', 'oa', 'g', 1)$$, :'ha'), '42501', null, 'B ne dodaje potrošnju u A-ovo domaćinstvo');

-- B ne može da poveže svoj red sa A-ovim roditeljem ili da kaže da je A kuvao.
select throws_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('ky', %L, 'ea', '2026-11-20', 'lunch', %L, 2, now())$$, :'hb', :'ub'), '23503', null, 'kuvanje B ne pokazuje na A-ov obrok');
select throws_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('kz', %L, 'eb', '2026-11-20', 'lunch', %L, 2, now())$$, :'hb', :'ua'), '42501', null, 'kuvao je član domaćinstva');
select throws_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('cy', %L, 'kb', 'oa', 'g', 1)$$, :'hb'), '23503', null, 'potrošnja B ne troši A-ovu ostavu');
select throws_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('cz', %L, 'ka', 'ob', 'g', 1)$$, :'hb'), '23503', null, 'potrošnja B ne pripada A-ovom kuvanju');
select tests.clear_auth();

-- A radi sve dozvoljeno sa svojim redovima.
select tests.authenticate_as(:'ua');
select is((select count(*) from public.cooked_events), 1::bigint, 'A vidi samo svoja kuvanja');
select lives_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('ka2', %L, 'ea2', '2026-11-21', 'lunch', %L, 2, now())$$, :'ha', :'ua'), 'A beleži kuvanje');
select lives_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('ca2', %L, 'ka2', 'oa', 'g', 100000000)$$, :'ha'), 'A beleži potrošnju');
select is(tests.affected($$update public.cooked_events set undone_at = now(), undo_reason = 'user' where id = 'ka2'$$), 1::bigint, 'A poništava kuvanje');
select lives_ok($$update public.pantry_items set quantity = 600, quantity_set_at = now() where id = 'oa'$$, 'A ručno upisuje količinu');
select tests.clear_auth();

-- Zapis se samo poništava; poništavanje se ne vraća zakasnelim slanjem.
select tests.authenticate_as(:'ua');
select lives_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('ka2', %L, 'ea2', '2026-11-21', 'lunch', %L, 3, now()) on conflict (id) do update set undone_at = excluded.undone_at, undo_reason = excluded.undo_reason, servings = excluded.servings$$, :'ha', :'ua'), 'zakasnelo slanje starog reda ne baca grešku');
select isnt((select undone_at from public.cooked_events where id = 'ka2'), null, 'poništeno kuvanje ostaje poništeno');
select is((select servings from public.cooked_events where id = 'ka2'), 2, 'porcije kuvanja se ne menjaju');
select tests.clear_auth();

-- Provere oblika (kao postgres: proverava se šema, ne RLS).
select throws_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at) values ('bad1', %L, 'ea', '2026-11-20', 'lunch', %L, 21, now())$$, :'ha', :'ua'), '23514', null, 'porcije 1–20');
select throws_ok(format($$insert into public.cooked_events (id, household_id, plan_entry_id, meal_date, meal_type, actor_user_id, servings, cooked_at, undone_at) values ('bad2', %L, 'ea', '2026-11-20', 'lunch', %L, 2, now(), now())$$, :'ha', :'ua'), '23514', null, 'poništavanje ima razlog');
select throws_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('bad3', %L, 'ka', 'oa', 'g', 0)$$, :'ha'), '23514', null, 'potrošnja je pozitivna');
select throws_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('dupc', %L, 'ka', 'oa', 'g', 1)$$, :'ha'), '23505', null, 'isto kuvanje iz iste stavke je jedan red');

-- Brisanje: tragovi i kaskade.
select tests.authenticate_as(:'ua');
select is(tests.affected($$delete from public.meal_plan_entries where id = 'ea'$$), 1::bigint, 'A briše obrok');
select is((select count(*) from public.cooked_events where id = 'ka'), 0::bigint, 'brisanje obroka briše njegovo kuvanje');
select is((select count(*) from public.pantry_consumptions where id = 'ca'), 0::bigint, 'i potrošnju tog kuvanja');
select is(
  array(select entity || ':' || record_id from public.deletions
         where entity in ('cooked_event', 'pantry_consumption')
         order by entity || ':' || record_id collate "C"),
  array['cooked_event:ka', 'pantry_consumption:ca'],
  'brisanja ostavljaju tragove za kuvanje i potrošnju'
);
select lives_ok(format($$insert into public.pantry_consumptions (id, household_id, event_id, pantry_item_id, base_unit, micros) values ('late', %L, 'ka', 'oa', 'g', 1)$$, :'ha'), 'kasna potrošnja obrisanog kuvanja ne baca grešku');
select is((select count(*) from public.pantry_consumptions where id = 'late'), 0::bigint, 'dete obrisanog kuvanja se preskače');
select tests.clear_auth();

-- Brisanje naloga A briše i njegova kuvanja i potrošnju; B ostaje.
set local role service_role;
select public.delete_account_data(:'ua');
reset role;
select is(
  (select count(*) from public.cooked_events where household_id = :'ha')
    + (select count(*) from public.pantry_consumptions where household_id = :'ha'),
  0::bigint,
  'brisanje naloga ne ostavlja kuvanje ni potrošnju'
);
select is((select count(*) from public.pantry_consumptions where household_id = :'hb'), 1::bigint, 'podaci B ostaju');

select * from finish();
rollback;
