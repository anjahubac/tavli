begin;
select * from no_plan();

select tests.create_user('consent-a@test.local') as first_user \gset
select tests.create_user('consent-b@test.local') as second_user \gset
select tests.create_user('consent-c@test.local') as outside_user \gset
select tests.household_of(:'first_user') as household_id \gset
delete from public.household_members where user_id = :'second_user';
insert into public.household_members (household_id, user_id, role)
values (:'household_id', :'second_user', 'owner');

select favorite_membership_id as first_membership
  from public.household_members where user_id = :'first_user' \gset
select favorite_membership_id as second_membership
  from public.household_members where user_id = :'second_user' \gset
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('shared-recipe', :'household_id', 'Jelo', 1, 'manual', '[]', '[]');

select tests.authenticate_as(:'first_user');
select is((select count(*) from public.user_planning_sharing), 0::bigint, 'absent row means default off');
select results_eq(
  $$select * from public.set_planning_preferences_sharing(0, true)$$,
  $$values (true, 1::bigint)$$, 'owner enables sharing at revision 1'
);
select throws_ok($$update public.user_planning_sharing set preferences = false$$,
  '42501', null, 'direct table write is denied');
select throws_ok($$select * from public.set_planning_preferences_sharing(0, false)$$,
  'P0001', null, 'stale client cannot undo acknowledged consent');
insert into public.taste_profiles (profile)
values ('{"likedDishKinds":["salad","pasta"],"likedCuisineCodes":["serbian","italian","unreviewed"],"likedFoodIds":["46d60c83-0d05-466e-9c28-585a8be28d8f","e760678c-1bce-4cde-8bca-b763885c7895"],"unsharedNote":"canary"}');
insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
values (:'first_membership' || ':shared-recipe', 'shared-recipe', :'household_id', :'first_membership', true);
insert into public.user_allergen_selections (group_codes) values (array['eggs']);

select tests.authenticate_as(:'second_user');
select is((select count(*) from public.user_planning_sharing), 0::bigint, 'peer does not read owner consent');
select throws_ok(format($$select public.planning_allergen_codes(%L, %L, array[%L::uuid])$$,
  :'second_user', :'household_id', :'first_user'), '42501', null, 'peer cannot execute server-only allergen query');

insert into public.taste_profiles (profile)
values ('{"dislikedDishKinds":["pasta"],"dislikedCuisineCodes":["italian"],"dislikedFoodIds":["46d60c83-0d05-466e-9c28-585a8be28d8f"],"unsharedNote":"canary"}');
insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
values (:'second_membership' || ':shared-recipe', 'shared-recipe', :'household_id', :'second_membership', true);
select throws_ok(format($$select public.planning_advisory_inputs(%L, %L, array[%L::uuid], false)$$,
  :'second_user', :'household_id', :'first_user'), '42501', null, 'peer cannot execute internal advisory resolver');

select tests.clear_auth();
set local role service_role;
select is(public.planning_allergen_codes(:'first_user', :'household_id', array[:'second_user'::uuid]),
  array[]::text[], 'empty and unselected members contribute no codes');
select is(public.planning_allergen_codes(:'first_user', :'household_id',
  array[:'first_user'::uuid, :'second_user'::uuid]), array['eggs'], 'server gets only authorized selection union');
select throws_ok(format($$select public.planning_allergen_codes(%L, %L, array[%L::uuid, %L::uuid])$$,
  :'first_user', :'household_id', :'first_user', :'outside_user'), '42501', null, 'foreign member invalidates the entire request');
select throws_ok(format($$select public.planning_allergen_codes(%L, %L, array[%L::uuid])$$,
  :'outside_user', :'household_id', :'first_user'), '42501', null, 'outside caller is denied');
select throws_ok(format($$select public.planning_allergen_codes(%L, %L, array[]::uuid[])$$,
  :'first_user', :'household_id'), '42501', null, 'empty participant set is denied');

select is(public.planning_advisory_inputs(:'first_user', :'household_id',
  array[:'first_user'::uuid, :'second_user'::uuid], true),
  '{"likedDishKinds":["pasta","salad"],"dislikedDishKinds":[],"likedFoodIds":[],"dislikedFoodIds":[],"likedCuisineCodes":["italian","serbian"],"dislikedCuisineCodes":[],"favoriteRecipeCounts":{"shared-recipe":1}}'::jsonb,
  'provider input excludes unshared tastes, favorites and raw notes');
select is(public.planning_advisory_inputs(:'second_user', :'household_id',
  array[:'second_user'::uuid], false),
  '{"likedDishKinds":[],"dislikedDishKinds":["pasta"],"likedFoodIds":[],"dislikedFoodIds":[],"likedCuisineCodes":[],"dislikedCuisineCodes":["italian"],"favoriteRecipeCounts":{"shared-recipe":1}}'::jsonb,
  'sole self can use their own advisory inputs for local ranking');
select is(public.planning_advisory_inputs(:'second_user', :'household_id',
  array[:'second_user'::uuid], true),
  '{"likedDishKinds":[],"dislikedDishKinds":[],"likedFoodIds":[],"dislikedFoodIds":[],"likedCuisineCodes":[],"dislikedCuisineCodes":[],"favoriteRecipeCounts":{}}'::jsonb,
  'sole self still needs consent for provider disclosure');

reset role;
select tests.authenticate_as(:'second_user');
select * from public.set_planning_preferences_sharing(0, true);
select tests.clear_auth();
select is(public.planning_advisory_inputs(:'first_user', :'household_id',
  array[:'first_user'::uuid, :'second_user'::uuid], true),
  '{"likedDishKinds":["salad"],"dislikedDishKinds":["pasta"],"likedFoodIds":[],"dislikedFoodIds":[],"likedCuisineCodes":["serbian"],"dislikedCuisineCodes":["italian"],"favoriteRecipeCounts":{"shared-recipe":2}}'::jsonb,
  'shared dislike prevails and each selected member contributes one favorite');

select is(public.planning_advisory_inputs(:'first_user', :'household_id',
  array[:'first_user'::uuid, :'second_user'::uuid], true,
  array['46d60c83-0d05-466e-9c28-585a8be28d8f']) -> 'dislikedFoodIds',
  '["46d60c83-0d05-466e-9c28-585a8be28d8f"]'::jsonb, 'a visible food dislike wins across shared participants');
select is(public.planning_advisory_inputs(:'first_user', :'household_id',
  array[:'first_user'::uuid, :'second_user'::uuid], true,
  array['46d60c83-0d05-466e-9c28-585a8be28d8f']) -> 'likedFoodIds',
  '[]'::jsonb, 'food outside the visible catalog scope is omitted');

select tests.authenticate_as(:'first_user');
select results_eq(
  $$select * from public.set_planning_preferences_sharing(1, false)$$,
  $$values (false, 2::bigint)$$, 'owner withdraws sharing at revision 2'
);
select throws_ok($$select * from public.set_planning_preferences_sharing(1, true)$$,
  'P0001', null, 'stale write cannot restore withdrawn consent');
select tests.authenticate_anon();
select throws_ok($$select * from public.set_planning_preferences_sharing(0, true)$$,
  '42501', null, 'anonymous cannot write consent');

select tests.clear_auth();
select is(public.planning_advisory_inputs(:'second_user', :'household_id',
  array[:'first_user'::uuid], false),
  '{"likedDishKinds":[],"dislikedDishKinds":[],"likedFoodIds":[],"dislikedFoodIds":[],"likedCuisineCodes":[],"dislikedCuisineCodes":[],"favoriteRecipeCounts":{}}'::jsonb,
  'withdrawal applies to the next authorized read');
delete from public.household_members where user_id = :'first_user';
select throws_ok(format($$select public.planning_advisory_inputs(%L, %L, array[%L::uuid], false)$$,
  :'second_user', :'household_id', :'first_user'), '42501', null, 'removed participant is denied');

select * from finish();
rollback;
