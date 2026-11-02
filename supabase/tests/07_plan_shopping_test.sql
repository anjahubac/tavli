-- 010: izvori, doprinosi i raspodela zalihe. Dva naloga (A i B): B ne vidi
-- i ne menja ništa od A; strani ključevi ne dozvoljavaju roditelja iz tuđeg
-- domaćinstva; provere vrste izvora, količina i porekla zalihe; brisanje
-- ostavlja tragove i kaskadno oslobađa raspodelu.
begin;
select * from no_plan();

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset

-- Podaci oba domaćinstva (kao postgres, bez RLS-a).
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('ra', :'ha', 'Sarma', 4, 'manual', '[{"name":"kupus","quantity":1,"unit":"kom"}]', '["Kuvati."]'),
         ('rb', :'hb', 'Pasulj', 2, 'manual', '[]', '[]');
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types)
  values ('pa', :'ha', '2026-11-02', '2026-11-30', '["lunch"]'),
         ('pb', :'hb', '2026-11-02', '2026-11-08', '["lunch"]');
insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type, recipe_id, servings, recipe_snapshot)
  values ('ea', :'ha', 'pa', '2026-11-03', 'lunch', 'ra', 2, '{"title":"Sarma","servings":4,"ingredients":[]}'),
         ('eb', :'hb', 'pb', '2026-11-03', 'lunch', 'rb', 2, '{"title":"Pasulj","servings":2,"ingredients":[]}');
insert into public.shopping_lists (id, household_id, name, meal_plan_id, week, period_start, period_end)
  values ('la', :'ha', 'Nedelja 1', 'pa', 1, '2026-11-02', '2026-11-08'),
         ('lb', :'hb', 'Nedelja 1', 'pb', 1, '2026-11-02', '2026-11-08');
insert into public.shopping_lists (id, household_id, name) values ('la_recipes', :'ha', 'Kupovina');
insert into public.shopping_items (id, household_id, list_id, name, quantity, unit, category, is_bought)
  values ('ia', :'ha', 'la', 'kupus', 1, 'kom', 'voće i povrće', false),
         ('ia_bought', :'ha', 'la', 'kupus', 1, 'kom', 'voće i povrće', true),
         ('ib', :'hb', 'lb', 'pasulj', 500, 'g', 'suvi proizvodi', false);
insert into public.pantry_items (id, household_id, name, quantity, unit, category, added_at, confirmed_at)
  values ('oa', :'ha', 'kupus', 1, 'kom', 'voće i povrće', now(), now()),
         ('ob', :'hb', 'pasulj', 200, 'g', 'suvi proizvodi', now(), now());
insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id)
  values ('sa', :'ha', 'la', 'planEntry', 'ea'),
         ('sb', :'hb', 'lb', 'planEntry', 'eb');
insert into public.shopping_contributions (id, household_id, shopping_item_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category)
  values ('ca', :'ha', 'ia', 'sa', 'kupus', 'count:kom', 'kom', 1000000, 'kupus', 'voće i povrće'),
         ('cb', :'hb', 'ib', 'sb', 'pasulj', 'mass', 'g', 500000000, 'pasulj', 'suvi proizvodi');
insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, micros)
  values ('aa', :'ha', 'ca', 'oa', 500000),
         ('ab', :'hb', 'cb', 'ob', 200000000);

-- Postojeći red dobija podrazumevane vrednosti.
select is((select default_servings from public.meal_plans where id = 'pa'), 2, 'plan ima podrazumevane porcije 2');
select is((select supply_id from public.supply_allocations where id = 'aa'), 'oa', 'supply_id je id stavke ostave');

-- B pokušava da dođe do A-ovih redova.
select tests.authenticate_as(:'ub');
select is((select count(*) from public.shopping_sources where household_id = :'ha'), 0::bigint, 'B ne vidi shopping_sources od A');
select is(tests.affected($$update public.shopping_sources set closed_at = now() where id = 'sa'$$), 0::bigint, 'B ne menja shopping_sources od A');
select is(tests.affected($$delete from public.shopping_sources where id = 'sa'$$), 0::bigint, 'B ne briše shopping_sources od A');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id) values ('sx', %L, 'la', 'planEntry', 'ea')$$, :'ha'), '42501', null, 'B ne dodaje shopping_sources u A-ovo domaćinstvo');
select is((select count(*) from public.shopping_contributions where household_id = :'ha'), 0::bigint, 'B ne vidi shopping_contributions od A');
select is(tests.affected($$update public.shopping_contributions set micros = 1 where id = 'ca'$$), 0::bigint, 'B ne menja shopping_contributions od A');
select is(tests.affected($$delete from public.shopping_contributions where id = 'ca'$$), 0::bigint, 'B ne briše shopping_contributions od A');
select throws_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('cx', %L, 'sa', 'luk', 'mass', 'g', 1, 'luk', 'ostalo')$$, :'ha'), '42501', null, 'B ne dodaje shopping_contributions u A-ovo domaćinstvo');
select is((select count(*) from public.supply_allocations where household_id = :'ha'), 0::bigint, 'B ne vidi supply_allocations od A');
select is(tests.affected($$update public.supply_allocations set micros = 1 where id = 'aa'$$), 0::bigint, 'B ne menja supply_allocations od A');
select is(tests.affected($$delete from public.supply_allocations where id = 'aa'$$), 0::bigint, 'B ne briše supply_allocations od A');
select throws_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, micros) values ('ax', %L, 'ca', 'oa', 1)$$, :'ha'), '42501', null, 'B ne dodaje supply_allocations u A-ovo domaćinstvo');

-- B ne može da poveže svoj red sa A-ovim roditeljem (složen strani ključ).
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id) values ('sy', %L, 'lb', 'planEntry', 'ea')$$, :'hb'), '23503', null, 'izvor B ne pokazuje na A-ov obrok');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id) values ('sy', %L, 'la', 'planEntry', 'eb')$$, :'hb'), '23503', null, 'izvor B ne ide u A-ovu listu');
select throws_ok(format($$insert into public.shopping_contributions (id, household_id, shopping_item_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('cy', %L, 'ia', 'sb', 'kupus', 'mass', 'g', 1, 'kupus', 'ostalo')$$, :'hb'), '23503', null, 'doprinos B ne pokazuje na A-ovu stavku');
select throws_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, micros) values ('ay', %L, 'cb', 'oa', 1)$$, :'hb'), '23503', null, 'raspodela B ne troši A-ovu ostavu');
select throws_ok(format($$update public.pantry_items set source_shopping_item_id = 'ia_bought' where id = 'ob'$$), '23503', null, 'prijem B ne pokazuje na A-ovu kupovinu');
select tests.clear_auth();

-- A radi sve dozvoljeno sa svojim redovima.
select tests.authenticate_as(:'ua');
select is((select count(*) from public.shopping_sources), 1::bigint, 'A vidi samo svoje izvore');
select lives_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, recipe_snapshot, servings, recipe_id, origin_key) values ('prep1', %L, 'la_recipes', 'recipePreparation', '{"title":"Sarma","servings":4,"ingredients":[]}', 3, 'ra', 'ra')$$, :'ha'), 'A dodaje samostalnu pripremu bez plana');
select is(tests.affected($$update public.shopping_sources set servings = 4 where id = 'prep1'$$), 1::bigint, 'A menja porcije pripreme');
select throws_ok(format($$update public.shopping_sources set household_id = %L where id = 'prep1'$$, :'hb'), '42501', null, 'A ne premešta izvor u B-ovo domaćinstvo');
select lives_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('c_unknown', %L, 'prep1', 'so', 'unknown', '', null, 'so', 'ostalo')$$, :'ha'), 'A dodaje doprinos nepoznate količine bez stavke');
select lives_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, purchased_shopping_item_id, covers_whole_unknown) values ('a_whole', %L, 'c_unknown', 'ia_bought', true)$$, :'ha'), 'A potvrđuje celu stavku nepoznate količine');
select lives_ok($$update public.pantry_items set source_shopping_item_id = 'ia_bought' where id = 'oa'$$, 'A beleži prijem kupovine u ostavu');
select lives_ok($$update public.shopping_items set purchase_provenance = '{"sources":[{"title":"Sarma","servings":2}]}' where id = 'ia_bought'$$, 'A zamrzava poreklo kupovine');
select tests.clear_auth();

-- Provere oblika (kao postgres: proverava se šema, ne RLS).
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind) values ('bad1', %L, 'la', 'planEntry')$$, :'ha'), '23514', null, 'izvor plana traži obrok');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, servings) values ('bad2', %L, 'la_recipes', 'recipePreparation', 2)$$, :'ha'), '23514', null, 'samostalna priprema traži zamrznut recept');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id, recipe_snapshot, servings) values ('bad3', %L, 'la_recipes', 'recipePreparation', 'ea', '{}', 2)$$, :'ha'), '23514', null, 'samostalna priprema nema obrok');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, recipe_snapshot, servings) values ('bad4', %L, 'la_recipes', 'recipePreparation', '{}', 21)$$, :'ha'), '23514', null, 'porcije 1–20');
select throws_ok(format($$insert into public.shopping_sources (id, household_id, list_id, kind, plan_entry_id) values ('dup', %L, 'la', 'planEntry', 'ea')$$, :'ha'), '23505', null, 'obrok ima jedan izvor u svojoj nedelji');
select throws_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('dupc', %L, 'sa', 'kupus', 'count:kom', 'kom', 1, 'Kupus', 'ostalo')$$, :'ha'), '23505', null, 'ponovljeno usklađivanje menja doprinos, ne dodaje novi');
select throws_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('neg', %L, 'sa', 'luk', 'mass', 'g', -1, 'luk', 'ostalo')$$, :'ha'), '23514', null, 'negativna količina se odbija');
select throws_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('unk', %L, 'sa', 'luk', 'mass', 'g', null, 'luk', 'ostalo')$$, :'ha'), '23514', null, 'nepoznata količina samo u grupi unknown');
select throws_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, micros) values ('none', %L, 'ca', 1)$$, :'ha'), '23514', null, 'raspodela ima poreklo');
select throws_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, purchased_shopping_item_id, micros) values ('both', %L, 'ca', 'oa', 'ia_bought', 1)$$, :'ha'), '23514', null, 'raspodela ima tačno jedno poreklo');
select throws_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, micros) values ('dupa', %L, 'ca', 'oa', 1)$$, :'ha'), '23505', null, 'ista zaliha se istom doprinosu dodeljuje jednom');
select throws_ok(format($$insert into public.pantry_items (id, household_id, name, category, added_at, source_shopping_item_id) values ('o2', %L, 'kupus', 'ostalo', now(), 'ia_bought')$$, :'ha'), '23505', null, 'jedna kupovina ima jedan prijem');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, meal_plan_id, week, period_start, period_end) values ('la2', %L, 'Nedelja 1', 'pa', 1, '2026-11-02', '2026-11-08')$$, :'ha'), '23505', null, 'plan ima jednu listu po nedelji');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, week) values ('l7', %L, 'x', 7)$$, :'ha'), '23514', null, 'nedelja 1–6');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, period_start) values ('lp', %L, 'x', now())$$, :'ha'), '23514', null, 'nedelja ima i početak i kraj');
select throws_ok($$update public.meal_plan_entries set servings = 0 where id = 'ea'$$, '23514', null, 'porcije obroka 1–20');

-- Brisanje: tragovi i kaskade.
select tests.authenticate_as(:'ua');
select is(tests.affected($$delete from public.pantry_items where id = 'oa'$$), 1::bigint, 'A briše stavku ostave');
select is((select count(*) from public.supply_allocations where id = 'aa'), 0::bigint, 'brisanje ostave oslobađa njenu raspodelu');
select is(tests.affected($$delete from public.shopping_items where id = 'ia'$$), 1::bigint, 'A briše otvorenu stavku');
select is((select shopping_item_id from public.shopping_contributions where id = 'ca'), null, 'doprinos ostaje bez stavke');
select is(tests.affected($$delete from public.meal_plan_entries where id = 'ea'$$), 1::bigint, 'A briše obrok');
select is((select count(*) from public.shopping_sources where id = 'sa'), 0::bigint, 'brisanje obroka briše njegov izvor');
select is((select count(*) from public.shopping_contributions where id = 'ca'), 0::bigint, 'i doprinose izvora');
select is((select count(*) from public.shopping_items where id = 'ia_bought'), 1::bigint, 'kupljena stavka ostaje kad se plan promeni');
select is(
  array(select entity || ':' || record_id from public.deletions
         where entity in ('shopping_source', 'shopping_contribution', 'supply_allocation')
         order by entity || ':' || record_id collate "C"),
  array['shopping_contribution:ca', 'shopping_source:sa', 'supply_allocation:aa'],
  'brisanja ostavljaju tragove za izvor, doprinos i raspodelu'
);
select lives_ok(format($$insert into public.shopping_contributions (id, household_id, source_id, ingredient_key, unit_group, base_unit, micros, name, category) values ('late', %L, 'sa', 'luk', 'mass', 'g', 1, 'luk', 'ostalo')$$, :'ha'), 'kasni doprinos obrisanog izvora ne baca grešku');
select is((select count(*) from public.shopping_contributions where id = 'late'), 0::bigint, 'dete obrisanog izvora se preskače');
select lives_ok(format($$insert into public.supply_allocations (id, household_id, contribution_id, pantry_item_id, micros) values ('late_a', %L, 'c_unknown', 'oa', 1)$$, :'ha'), 'kasna raspodela obrisane ostave ne baca grešku');
select is((select count(*) from public.supply_allocations where id = 'late_a'), 0::bigint, 'raspodela obrisane zalihe se preskače');
select tests.clear_auth();

select tests.authenticate_as(:'ub');
select is((select count(*) from public.deletions where entity like 'shopping_%' or entity = 'supply_allocation'), 0::bigint, 'B ne vidi A-ove tragove nabavke');
select is((select count(*) from public.supply_allocations), 1::bigint, 'B i dalje ima svoju raspodelu');
select tests.clear_auth();

-- Brisanje naloga A briše i njegove izvore, doprinose i raspodelu.
set local role service_role;
select public.delete_account_data(:'ua');
reset role;
select is(
  (select count(*) from public.shopping_sources where household_id = :'ha')
    + (select count(*) from public.shopping_contributions where household_id = :'ha')
    + (select count(*) from public.supply_allocations where household_id = :'ha'),
  0::bigint,
  'brisanje naloga ne ostavlja podatke nabavke'
);
select is((select count(*) from public.supply_allocations where household_id = :'hb'), 1::bigint, 'podaci B ostaju');

select * from finish();
rollback;
