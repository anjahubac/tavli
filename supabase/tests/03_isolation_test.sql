-- Dva naloga (A i B): B ne vidi i ne menja ništa od A, A radi sve dozvoljeno
-- sa svojim redovima i ne može da premesti red u tuđe domaćinstvo (SC-006).
begin;
select * from no_plan();

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset

-- Početni podaci oba domaćinstva (kao postgres, bez RLS-a).
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps) values ('recipes_a', :'ha', 't', 1, 'manual', '[]', '[]');
insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind) values ('recipe_versions_a', :'ha', 'recipes_a', '{}', 'ai');
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('meal_plans_a', :'ha', now(), now(), '[]');
insert into public.shopping_lists (id, household_id, name) values ('shopping_lists_a', :'ha', 'l');
insert into public.shopping_items (id, household_id, list_id, name, category) values ('shopping_items_a', :'ha', 'shopping_lists_a', 'so', 'ostalo');
insert into public.pantry_items (id, household_id, name, category, added_at) values ('pantry_items_a', :'ha', 'so', 'ostalo', now());
insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type) values ('meal_plan_entries_a', :'ha', 'meal_plans_a', now(), 'lunch');
insert into public.ratings (id, user_id, recipe_id, stars, cooked_at) values ('ratings_a', :'ua', 'recipes_a', 5, now());
insert into public.taste_profiles (user_id, profile) values (:'ua', '{}');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps) values ('recipes_b', :'hb', 't', 1, 'manual', '[]', '[]');
insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind) values ('recipe_versions_b', :'hb', 'recipes_b', '{}', 'ai');
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('meal_plans_b', :'hb', now(), now(), '[]');
insert into public.shopping_lists (id, household_id, name) values ('shopping_lists_b', :'hb', 'l');
insert into public.shopping_items (id, household_id, list_id, name, category) values ('shopping_items_b', :'hb', 'shopping_lists_b', 'so', 'ostalo');
insert into public.pantry_items (id, household_id, name, category, added_at) values ('pantry_items_b', :'hb', 'so', 'ostalo', now());
insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type) values ('meal_plan_entries_b', :'hb', 'meal_plans_b', now(), 'lunch');
insert into public.ratings (id, user_id, recipe_id, stars, cooked_at) values ('ratings_b', :'ub', 'recipes_b', 5, now());
insert into public.taste_profiles (user_id, profile) values (:'ub', '{}');

-- B pokušava da dođe do A-ovih redova.
select tests.authenticate_as(:'ub');
select is((select count(*) from public.recipes where household_id = :'ha'), 0::bigint, 'B ne vidi recipes od A');
select is(tests.affected($$update public.recipes set title = 'z' where id = 'recipes_a'$$), 0::bigint, 'B ne menja recipes od A');
select is(tests.affected($$delete from public.recipes where id = 'recipes_a'$$), 0::bigint, 'B ne briše recipes od A');
select throws_ok(format($$insert into public.recipes (id, household_id, title, servings, source, ingredients, steps) values ('recipes_x', %L, 't', 1, 'manual', '[]', '[]')$$, :'ha'), '42501', null, 'B ne dodaje recipes u A-ovo domaćinstvo');
select is((select count(*) from public.recipe_versions where household_id = :'ha'), 0::bigint, 'B ne vidi recipe_versions od A');
select is(tests.affected($$update public.recipe_versions set instruction = 'z' where id = 'recipe_versions_a'$$), 0::bigint, 'B ne menja recipe_versions od A');
select is(tests.affected($$delete from public.recipe_versions where id = 'recipe_versions_a'$$), 0::bigint, 'B ne briše recipe_versions od A');
select throws_ok(format($$insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind) values ('recipe_versions_x', %L, 'recipes_a', '{}', 'ai')$$, :'ha'), '42501', null, 'B ne dodaje recipe_versions u A-ovo domaćinstvo');
select is((select count(*) from public.meal_plans where household_id = :'ha'), 0::bigint, 'B ne vidi meal_plans od A');
select is(tests.affected($$update public.meal_plans set use_pantry = false where id = 'meal_plans_a'$$), 0::bigint, 'B ne menja meal_plans od A');
select is(tests.affected($$delete from public.meal_plans where id = 'meal_plans_a'$$), 0::bigint, 'B ne briše meal_plans od A');
select throws_ok(format($$insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('meal_plans_x', %L, now(), now(), '[]')$$, :'ha'), '42501', null, 'B ne dodaje meal_plans u A-ovo domaćinstvo');
select is((select count(*) from public.shopping_lists where household_id = :'ha'), 0::bigint, 'B ne vidi shopping_lists od A');
select is(tests.affected($$update public.shopping_lists set name = 'z' where id = 'shopping_lists_a'$$), 0::bigint, 'B ne menja shopping_lists od A');
select is(tests.affected($$delete from public.shopping_lists where id = 'shopping_lists_a'$$), 0::bigint, 'B ne briše shopping_lists od A');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name) values ('shopping_lists_x', %L, 'l')$$, :'ha'), '42501', null, 'B ne dodaje shopping_lists u A-ovo domaćinstvo');
select is((select count(*) from public.shopping_items where household_id = :'ha'), 0::bigint, 'B ne vidi shopping_items od A');
select is(tests.affected($$update public.shopping_items set is_bought = true where id = 'shopping_items_a'$$), 0::bigint, 'B ne menja shopping_items od A');
select is(tests.affected($$delete from public.shopping_items where id = 'shopping_items_a'$$), 0::bigint, 'B ne briše shopping_items od A');
select throws_ok(format($$insert into public.shopping_items (id, household_id, list_id, name, category) values ('shopping_items_x', %L, 'shopping_lists_a', 'so', 'ostalo')$$, :'ha'), '42501', null, 'B ne dodaje shopping_items u A-ovo domaćinstvo');
select is((select count(*) from public.pantry_items where household_id = :'ha'), 0::bigint, 'B ne vidi pantry_items od A');
select is(tests.affected($$update public.pantry_items set name = 'z' where id = 'pantry_items_a'$$), 0::bigint, 'B ne menja pantry_items od A');
select is(tests.affected($$delete from public.pantry_items where id = 'pantry_items_a'$$), 0::bigint, 'B ne briše pantry_items od A');
select throws_ok(format($$insert into public.pantry_items (id, household_id, name, category, added_at) values ('pantry_items_x', %L, 'so', 'ostalo', now())$$, :'ha'), '42501', null, 'B ne dodaje pantry_items u A-ovo domaćinstvo');
select is((select count(*) from public.meal_plan_entries where household_id = :'ha'), 0::bigint, 'B ne vidi meal_plan_entries od A');
select is(tests.affected($$update public.meal_plan_entries set is_cooked = true where id = 'meal_plan_entries_a'$$), 0::bigint, 'B ne menja meal_plan_entries od A');
select is(tests.affected($$delete from public.meal_plan_entries where id = 'meal_plan_entries_a'$$), 0::bigint, 'B ne briše meal_plan_entries od A');
select throws_ok(format($$insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type) values ('meal_plan_entries_x', %L, 'meal_plans_a', now(), 'lunch')$$, :'ha'), '42501', null, 'B ne dodaje meal_plan_entries u A-ovo domaćinstvo');
select is((select count(*) from public.ratings where user_id = :'ua'), 0::bigint, 'B ne vidi ocene od A');
select is(tests.affected($$update public.ratings set stars = 1 where id = 'ratings_a'$$), 0::bigint, 'B ne menja ocenu od A');
select is(tests.affected($$delete from public.ratings where id = 'ratings_a'$$), 0::bigint, 'B ne briše ocenu od A');
select throws_ok(format($$insert into public.ratings (id, user_id, recipe_id, stars, cooked_at) values ('ratings_x', %L, 'recipes_b', 3, now())$$, :'ua'), '42501', null, 'B ne dodaje ocenu u ime A');
select throws_ok($$insert into public.ratings (id, recipe_id, stars, cooked_at) values ('ratings_y', 'recipes_a', 3, now())$$, '42501', null, 'B ne ocenjuje recept iz A-ovog domaćinstva');
select is((select count(*) from public.taste_profiles where user_id = :'ua'), 0::bigint, 'B ne vidi profil ukusa od A');
select is(tests.affected(format($$update public.taste_profiles set profile = '{"x":1}' where user_id = %L$$, :'ua')), 0::bigint, 'B ne menja profil ukusa od A');
select is(tests.affected(format($$delete from public.taste_profiles where user_id = %L$$, :'ua')), 0::bigint, 'B ne briše profil ukusa od A');
select throws_ok(format($$insert into public.taste_profiles (user_id, profile) values (%L, '{}')$$, :'ua'), '42501', null, 'B ne dodaje profil ukusa za A');
select is((select count(*) from public.profiles where id = :'ua'), 0::bigint, 'B ne vidi profil od A');
select is(tests.affected(format($$update public.profiles set display_name = 'X' where id = %L$$, :'ua')), 0::bigint, 'B ne menja ime od A');
select is((select count(*) from public.households where id = :'ha'), 0::bigint, 'B ne vidi domaćinstvo od A');
select is((select count(*) from public.household_members where household_id = :'ha'), 0::bigint, 'B ne vidi članove domaćinstva od A');
select is((select count(*) from public.household_members), 1::bigint, 'B vidi samo svoje članstvo');
select throws_ok(format($$insert into public.household_members (household_id, user_id, role) values (%L, %L, 'owner')$$, :'ha', :'ub'), '42501', null, 'B ne može da se učlani u A-ovo domaćinstvo');
select throws_ok($$delete from public.profiles$$, '42501', null, 'profil ne može da se obriše iz aplikacije');
select tests.clear_auth();

-- A-ova brisanja ostavljaju tragove koje B ne sme da vidi.
select tests.authenticate_as(:'ua');
select is(tests.affected($$delete from public.pantry_items where id = 'pantry_items_a'$$), 1::bigint, 'A briše svoju namirnicu');
select tests.authenticate_as(:'ub');
select is((select count(*) from public.deletions), 0::bigint, 'B ne vidi tragove brisanja od A');
select throws_ok($$insert into public.deletions (entity, record_id, user_id) values ('x', 'y', auth.uid())$$, '42501', null, 'tragovi se ne pišu iz aplikacije');
select tests.clear_auth();

-- A radi sve dozvoljeno sa svojim redovima.
select tests.authenticate_as(:'ua');
select is((select count(*) from public.recipes), (select count(*) from public.recipes where household_id = :'ha'), 'A vidi samo recipes svog domaćinstva');
select lives_ok(format($$insert into public.recipes (id, household_id, title, servings, source, ingredients, steps) values ('recipes_new', %L, 't', 1, 'manual', '[]', '[]')$$, :'ha'), 'A dodaje recipes');
select is(tests.affected($$update public.recipes set title = 'z' where id = 'recipes_new'$$), 1::bigint, 'A menja recipes');
select throws_ok(format($$update public.recipes set household_id = %L where id = 'recipes_new'$$, :'hb'), '42501', null, 'A ne premešta recipes u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.recipes where id = 'recipes_new'$$), 1::bigint, 'A briše recipes');
select is((select count(*) from public.recipe_versions), (select count(*) from public.recipe_versions where household_id = :'ha'), 'A vidi samo recipe_versions svog domaćinstva');
select lives_ok(format($$insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind) values ('recipe_versions_new', %L, 'recipes_a', '{}', 'ai')$$, :'ha'), 'A dodaje recipe_versions');
select is(tests.affected($$update public.recipe_versions set instruction = 'z' where id = 'recipe_versions_new'$$), 1::bigint, 'A menja recipe_versions');
select throws_ok(format($$update public.recipe_versions set household_id = %L where id = 'recipe_versions_new'$$, :'hb'), '42501', null, 'A ne premešta recipe_versions u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.recipe_versions where id = 'recipe_versions_new'$$), 1::bigint, 'A briše recipe_versions');
select is((select count(*) from public.meal_plans), (select count(*) from public.meal_plans where household_id = :'ha'), 'A vidi samo meal_plans svog domaćinstva');
select lives_ok(format($$insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('meal_plans_new', %L, now(), now(), '[]')$$, :'ha'), 'A dodaje meal_plans');
select is(tests.affected($$update public.meal_plans set use_pantry = false where id = 'meal_plans_new'$$), 1::bigint, 'A menja meal_plans');
select throws_ok(format($$update public.meal_plans set household_id = %L where id = 'meal_plans_new'$$, :'hb'), '42501', null, 'A ne premešta meal_plans u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.meal_plans where id = 'meal_plans_new'$$), 1::bigint, 'A briše meal_plans');
select is((select count(*) from public.shopping_lists), (select count(*) from public.shopping_lists where household_id = :'ha'), 'A vidi samo shopping_lists svog domaćinstva');
select lives_ok(format($$insert into public.shopping_lists (id, household_id, name) values ('shopping_lists_new', %L, 'l')$$, :'ha'), 'A dodaje shopping_lists');
select is(tests.affected($$update public.shopping_lists set name = 'z' where id = 'shopping_lists_new'$$), 1::bigint, 'A menja shopping_lists');
select throws_ok(format($$update public.shopping_lists set household_id = %L where id = 'shopping_lists_new'$$, :'hb'), '42501', null, 'A ne premešta shopping_lists u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.shopping_lists where id = 'shopping_lists_new'$$), 1::bigint, 'A briše shopping_lists');
select is((select count(*) from public.shopping_items), (select count(*) from public.shopping_items where household_id = :'ha'), 'A vidi samo shopping_items svog domaćinstva');
select lives_ok(format($$insert into public.shopping_items (id, household_id, list_id, name, category) values ('shopping_items_new', %L, 'shopping_lists_a', 'so', 'ostalo')$$, :'ha'), 'A dodaje shopping_items');
select is(tests.affected($$update public.shopping_items set is_bought = true where id = 'shopping_items_new'$$), 1::bigint, 'A menja shopping_items');
select throws_ok(format($$update public.shopping_items set household_id = %L where id = 'shopping_items_new'$$, :'hb'), '42501', null, 'A ne premešta shopping_items u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.shopping_items where id = 'shopping_items_new'$$), 1::bigint, 'A briše shopping_items');
select is((select count(*) from public.pantry_items), (select count(*) from public.pantry_items where household_id = :'ha'), 'A vidi samo pantry_items svog domaćinstva');
select lives_ok(format($$insert into public.pantry_items (id, household_id, name, category, added_at) values ('pantry_items_new', %L, 'so', 'ostalo', now())$$, :'ha'), 'A dodaje pantry_items');
select is(tests.affected($$update public.pantry_items set name = 'z' where id = 'pantry_items_new'$$), 1::bigint, 'A menja pantry_items');
select throws_ok(format($$update public.pantry_items set household_id = %L where id = 'pantry_items_new'$$, :'hb'), '42501', null, 'A ne premešta pantry_items u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.pantry_items where id = 'pantry_items_new'$$), 1::bigint, 'A briše pantry_items');
select is((select count(*) from public.meal_plan_entries), (select count(*) from public.meal_plan_entries where household_id = :'ha'), 'A vidi samo meal_plan_entries svog domaćinstva');
select lives_ok(format($$insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type) values ('meal_plan_entries_new', %L, 'meal_plans_a', now(), 'lunch')$$, :'ha'), 'A dodaje meal_plan_entries');
select is(tests.affected($$update public.meal_plan_entries set is_cooked = true where id = 'meal_plan_entries_new'$$), 1::bigint, 'A menja meal_plan_entries');
select throws_ok(format($$update public.meal_plan_entries set household_id = %L where id = 'meal_plan_entries_new'$$, :'hb'), '42501', null, 'A ne premešta meal_plan_entries u B-ovo domaćinstvo');
select is(tests.affected($$delete from public.meal_plan_entries where id = 'meal_plan_entries_new'$$), 1::bigint, 'A briše meal_plan_entries');
select is((select count(*) from public.ratings), 1::bigint, 'A vidi samo svoju ocenu');
select lives_ok($$insert into public.ratings (id, recipe_id, stars, cooked_at) values ('ratings_new', 'recipes_a', 4, now())$$, 'A ocenjuje svoj recept');
select is(tests.affected($$update public.ratings set stars = 2 where id = 'ratings_new'$$), 1::bigint, 'A menja ocenu');
select throws_ok($$update public.ratings set recipe_id = 'recipes_b' where id = 'ratings_new'$$, '42501', null, 'A ne prebacuje ocenu na B-ov recept');
select is(tests.affected($$delete from public.ratings where id = 'ratings_new'$$), 1::bigint, 'A briše ocenu');
select is(tests.affected($$update public.taste_profiles set profile = '{"ljuto":true}'$$), 1::bigint, 'A menja svoj profil ukusa');
select is(tests.affected($$delete from public.taste_profiles$$), 1::bigint, 'A briše svoj profil ukusa');
select lives_ok($$insert into public.taste_profiles (profile) values ('{}')$$, 'A pravi profil ukusa');
select is((select count(*) from public.profiles), 1::bigint, 'A vidi samo svoj profil');
select is(tests.affected($$update public.profiles set display_name = 'Ana'$$), 1::bigint, 'A menja svoje ime');
select throws_ok($$update public.profiles set email = 'x@y.z'$$, '42501', null, 'A ne menja svoju e-poštu');
select is((select count(*) from public.households), 1::bigint, 'A vidi svoje domaćinstvo');
select throws_ok($$update public.households set name = 'X'$$, '42501', null, 'A ne menja domaćinstvo iz aplikacije');
select throws_ok($$insert into public.households (name) values ('X')$$, '42501', null, 'A ne pravi domaćinstvo iz aplikacije');
select throws_ok($$delete from public.household_members$$, '42501', null, 'A ne briše članstvo iz aplikacije');
select is((select count(*) from public.deletions where record_id = 'pantry_items_a'), 1::bigint, 'A vidi svoj trag brisanja');
select tests.clear_auth();

-- anon ne vidi ništa.
select tests.authenticate_anon();
select throws_ok($$select * from public.recipes$$, '42501', null, 'anon ne čita recepte');
select throws_ok($$select * from public.profiles$$, '42501', null, 'anon ne čita profile');
select tests.clear_auth();

select * from finish();
rollback;
