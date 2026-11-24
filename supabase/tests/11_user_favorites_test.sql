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

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('fav-first', :'household_id', 'Prvo jelo', 1, 'manual', '[]', '[]'),
       ('fav-second', :'household_id', 'Drugo jelo', 1, 'manual', '[]', '[]'),
       ('fav-outside', :'outside_household', 'Drugo domaćinstvo', 1, 'manual', '[]', '[]');

select tests.authenticate_as(:'first_user');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'first_user' || ':fav-first', 'fav-first', :'household_id', true);
select is((select recipe_id from public.user_favorites where is_favorite), 'fav-first', 'first member sees own favorite');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
  values (%L, 'fav-outside', %L, true)$q$, :'first_user' || ':fav-outside', :'outside_household'),
  '42501', null, 'foreign recipe cannot be added');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
  values (%L, 'fav-outside', %L, true)$q$, :'first_user' || ':fav-outside', :'household_id'),
  '42501', null, 'household label cannot unlock a foreign recipe');
select throws_ok(format($q$insert into public.user_favorites (id, user_id, recipe_id, recipe_household_id, is_favorite)
  values (%L, %L, 'fav-first', %L, true)$q$, :'second_user' || ':fav-first', :'second_user', :'household_id'),
  '42501', null, 'first member cannot set a favorite for peer');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
  values ('custom-id', 'fav-second', %L, true)$q$, :'household_id'),
  '23514', null, 'favorite id must be user and recipe');

select throws_ok(format($q$update public.user_favorites set id = %L, recipe_id = 'fav-second'$q$,
  :'first_user' || ':fav-second'), '23514', null, 'favorite identity cannot be redirected');

select tests.authenticate_as(:'second_user');
select is((select count(*) from public.user_favorites), 0::bigint, 'peer favorites are private');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'second_user' || ':fav-second', 'fav-second', :'household_id', true);
update public.user_favorites set is_favorite = false;
select is((select count(*) from public.user_favorites where is_favorite), 0::bigint, 'unfavorite clears active state');
update public.user_favorites set is_favorite = true;
select is((select recipe_id from public.user_favorites where is_favorite), 'fav-second', 'same identity can be favorited again');

select tests.clear_auth();
delete from public.household_members where user_id = :'second_user';
select is((select count(*) from public.user_favorites where user_id = :'second_user'), 0::bigint, 'leaving removes favorites');
select is((select count(*) from public.user_favorites where user_id = :'first_user'), 1::bigint, 'staying member keeps favorites');
select is((select count(*) from public.deletions where entity = 'favorite' and user_id = :'second_user'), 1::bigint, 'removal syncs to other devices');

-- An unsent write from before leaving is rejected while access is gone.
insert into public.household_members (household_id, user_id, role)
values (:'outside_household', :'second_user', 'owner');
select tests.authenticate_as(:'second_user');
select throws_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
  values (%L, 'fav-second', %L, true)$q$, :'second_user' || ':fav-second', :'household_id'),
  '42501', null, 'former member cannot replay a favorite');
select is((select count(*) from public.deletions where entity = 'favorite' and user_id = :'second_user'), 1::bigint, 'rejected replay keeps the tombstone');

-- Rejoining the same household allows saving the same recipe again.
select tests.clear_auth();
delete from public.household_members where user_id = :'second_user';
insert into public.household_members (household_id, user_id, role)
values (:'household_id', :'second_user', 'owner');
select tests.authenticate_as(:'second_user');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'second_user' || ':fav-second', 'fav-second', :'household_id', true);
select is((select count(*) from public.user_favorites where is_favorite), 1::bigint, 'rejoined member can favorite the same recipe');

select tests.clear_auth();
delete from public.recipes where id = 'fav-first';
select is((select count(*) from public.user_favorites where user_id = :'first_user'), 0::bigint, 'recipe deletion clears favorite');
select tests.authenticate_as(:'first_user');
select lives_ok(format($q$insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
  values (%L, 'fav-first', %L, true)$q$, :'first_user' || ':fav-first', :'household_id'),
  'replay for a deleted recipe is skipped');
select is((select count(*) from public.user_favorites), 0::bigint, 'deleted recipe cannot be favorited again');
select tests.clear_auth();
delete from auth.users where id = :'second_user';
select is((select count(*) from public.user_favorites where user_id = :'second_user'), 0::bigint, 'account deletion clears favorite');

select * from finish();
rollback;
