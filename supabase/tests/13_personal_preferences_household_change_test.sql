begin;
select * from no_plan();

-- Personal preferences belong to the profile, not to a household.
select tests.create_user('moving-a@test.local') as mover \gset
select tests.create_user('moving-b@test.local') as host \gset
select tests.household_of(:'mover') as source_household \gset
select tests.household_of(:'host') as target_household \gset

select tests.authenticate_as(:'mover');
insert into public.taste_profiles (profile)
values ('{"likedDishKinds":["salad"],"dislikedCuisineCodes":["italian"]}');
insert into public.user_allergen_selections (group_codes) values (array['milk', 'nuts']);
select * from public.set_planning_preferences_sharing(0, true);

select tests.authenticate_as(:'host');
select public.household_invite_token() as target_token \gset

-- The mover is the last member, so the join also deletes the source household.
select tests.authenticate_as(:'mover');
select is(public.confirm_household_join(:'target_token', :'source_household',
  'leave_recipes', true, gen_random_uuid())->>'status', 'joined', 'mover joins through the invite');
select is((select count(*) from public.households where id = :'source_household'), 0::bigint,
  'the empty source household is deleted');
select is((select profile ->> 'likedDishKinds' from public.taste_profiles), '["salad"]',
  'taste preferences stay after a household change');
select is((select profile ->> 'dislikedCuisineCodes' from public.taste_profiles), '["italian"]',
  'cuisine dislikes stay after a household change');
select is((select group_codes from public.user_allergen_selections), array['milk', 'nuts'],
  'allergen selection stays after a household change');
select is((select preferences from public.user_planning_sharing), true,
  'planning consent stays after a household change');
select is((select count(*) from public.deletions
  where user_id = :'mover' and entity in ('taste_profile', 'allergen_selection')), 0::bigint,
  'no preference tombstone is synced to other devices');

select tests.authenticate_as(:'host');
select is((select count(*) from public.taste_profiles), 0::bigint, 'new household peer cannot read moved preferences');
select is((select count(*) from public.user_allergen_selections), 0::bigint, 'new household peer cannot read moved allergens');
select is((select count(*) from public.user_planning_sharing), 0::bigint, 'new household peer cannot read moved consent');

-- Removal by the owner moves the member again; preferences still stay.
select is(public.remove_household_member(:'mover')->>'status', 'removed', 'owner removes the mover');
select tests.authenticate_as(:'mover');
select is((select count(*) from public.taste_profiles), 1::bigint, 'taste preferences stay after removal');
select is((select group_codes from public.user_allergen_selections), array['milk', 'nuts'],
  'allergen selection stays after removal');
select is((select preferences from public.user_planning_sharing), true, 'planning consent stays after removal');

select * from finish();
rollback;
