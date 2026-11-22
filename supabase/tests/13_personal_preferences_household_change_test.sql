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

select tests.clear_auth();
delete from public.household_members where user_id = :'mover';
insert into public.household_members (household_id, user_id, role)
values (:'target_household', :'mover', 'owner');

select tests.authenticate_as(:'mover');
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

select * from finish();
rollback;
