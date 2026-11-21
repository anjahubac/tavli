begin;
select * from no_plan();

select tests.create_user('favorites-a@test.local') as first_user \gset
select tests.create_user('favorites-b@test.local') as second_user \gset
select tests.create_user('favorites-c@test.local') as outside_user \gset
select tests.household_of(:'first_user') as household_id \gset
select tests.household_of(:'outside_user') as outside_household \gset

delete from public.household_members where user_id = :'second_user';
insert into public.household_members (household_id, user_id, role)
values (:'household_id', :'second_user', 'owner');
select favorite_membership_id as first_membership
  from public.household_members where user_id = :'first_user' \gset
select favorite_membership_id as second_membership
  from public.household_members where user_id = :'second_user' \gset

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('fav-first', :'household_id', 'Prvo jelo', 1, 'manual', '[]', '[]'),
       ('fav-second', :'household_id', 'Drugo jelo', 1, 'manual', '[]', '[]'),
       ('fav-outside', :'outside_household', 'Drugo domaćinstvo', 1, 'manual', '[]', '[]');

select tests.authenticate_as(:'first_user');
insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
values (:'first_membership' || ':fav-first', 'fav-first', :'household_id', :'first_membership', true);
select is((select recipe_id from public.user_favorites where is_favorite), 'fav-first', 'first member sees own favorite');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
  values (%L, 'fav-outside', %L, %L, true)$q$, :'first_membership' || ':fav-outside', :'outside_household', :'first_membership'),
  '42501', null, 'foreign recipe cannot be added');
select throws_ok(format($q$insert into public.user_favorites (id, user_id, recipe_id, recipe_household_id, membership_id, is_favorite)
  values (%L, %L, 'fav-first', %L, %L, true)$q$, :'second_membership' || ':fav-first', :'second_user', :'household_id', :'second_membership'),
  '42501', null, 'first member cannot set a favorite for peer');

select throws_ok(format($q$update public.user_favorites set id = %L, recipe_id = 'fav-second'$q$,
  :'first_membership' || ':fav-second'), '23514', null, 'favorite identity cannot be redirected');

select tests.authenticate_as(:'second_user');
select is((select count(*) from public.user_favorites), 0::bigint, 'peer favorites are private');
insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
values (:'second_membership' || ':fav-second', 'fav-second', :'household_id', :'second_membership', true);
update public.user_favorites set is_favorite = false;
select is((select count(*) from public.user_favorites where is_favorite), 0::bigint, 'unfavorite clears active state');
update public.user_favorites set is_favorite = true;
select is((select recipe_id from public.user_favorites where is_favorite), 'fav-second', 'same identity can be favorited again');

select tests.clear_auth();
delete from public.household_members where user_id = :'second_user';
select is((select count(*) from public.user_favorites where user_id = :'second_user'), 0::bigint, 'leaving removes favorites');
select is((select count(*) from public.deletions where entity = 'favorite' and user_id = :'second_user'), 1::bigint, 'removal syncs to other devices');

insert into public.household_members (household_id, user_id, role)
values (:'household_id', :'second_user', 'owner')
returning favorite_membership_id as new_membership \gset
select tests.authenticate_as(:'second_user');
select lives_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
  values (%L, 'fav-second', %L, %L, true)$q$, :'second_membership' || ':fav-second', :'household_id', :'second_membership'),
  'old queued replay is discarded after rejoin');
select is((select count(*) from public.user_favorites), 0::bigint, 'old membership cannot restore a favorite');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
  values (%L, 'fav-first', %L, %L, true)$q$, :'second_membership' || ':fav-first', :'household_id', :'second_membership'),
  '23503', null, 'an unsent favorite from the old membership is rejected');
insert into public.user_favorites (id, recipe_id, recipe_household_id, membership_id, is_favorite)
values (:'new_membership' || ':fav-second', 'fav-second', :'household_id', :'new_membership', true);
select is((select count(*) from public.user_favorites), 1::bigint, 'same recipe can be saved on new membership');

select tests.clear_auth();
delete from public.recipes where id = 'fav-first';
select is((select count(*) from public.user_favorites where user_id = :'first_user'), 0::bigint, 'recipe deletion clears favorite');
delete from auth.users where id = :'second_user';
select is((select count(*) from public.user_favorites where user_id = :'second_user'), 0::bigint, 'account deletion clears favorite');

select * from finish();
rollback;
