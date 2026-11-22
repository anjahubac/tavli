-- A brought recipe keeps the mover's favorite and rating; left-behind recipes lose them.
begin;
select no_plan();

select tests.create_user('marks-mover@test.local') as mover \gset
select tests.create_user('marks-peer@test.local') as peer \gset
select tests.create_user('marks-host@test.local') as host \gset
select tests.create_user('marks-stayer@test.local') as stayer \gset
select tests.household_of(:'mover') as source_household \gset
select tests.household_of(:'host') as target_household \gset

-- The peer and the stayer share the mover's source household.
delete from public.household_members where user_id in (:'peer', :'stayer');
insert into public.household_members (household_id, user_id, role)
values (:'source_household', :'peer', 'member'), (:'source_household', :'stayer', 'member');

select tests.authenticate_as(:'host');
select public.household_invite_token() as target_token \gset

-- The mover creates one recipe; the peer creates another.
select tests.authenticate_as(:'mover');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('marks-own', :'source_household', 'Moj recept', 1, 'manual', '[]', '[]');
select tests.authenticate_as(:'peer');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('marks-peer', :'source_household', 'Tuđi recept', 1, 'manual', '[]', '[]');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'peer' || ':marks-own', 'marks-own', :'source_household', true);

select tests.authenticate_as(:'mover');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'mover' || ':marks-own', 'marks-own', :'source_household', true),
       (:'mover' || ':marks-peer', 'marks-peer', :'source_household', true);
insert into public.ratings (id, recipe_id, stars, comment, is_comfort_food, cooked_at)
values ('marks-rating-own', 'marks-own', 5, 'Odlično', true, '2026-11-01T12:00:00Z'),
       ('marks-rating-peer', 'marks-peer', 2, null, false, '2026-11-02T12:00:00Z');

select is(public.confirm_household_join(:'target_token', :'source_household',
  'bring_recipes', false, gen_random_uuid())->>'status', 'joined', 'mover joins with own recipes');

select id as copied_recipe from public.recipes
 where household_id = :'target_household' and title = 'Moj recept' \gset
select isnt(:'copied_recipe'::text, 'marks-own'::text, 'the brought recipe is a copy');
select is((select count(*) from public.recipes where title = 'Tuđi recept'), 0::bigint,
  'peer recipe is not brought');

select results_eq(
  $$select id, recipe_household_id::text, is_favorite from public.user_favorites$$,
  format($$values (%L, %L, true)$$, :'mover' || ':' || :'copied_recipe', :'target_household'),
  'only the favorite on the brought recipe remains, under the new household');
select results_eq(
  $$select recipe_id, stars, comment, is_comfort_food, cooked_at from public.ratings$$,
  format($$values (%L, 5, 'Odlično'::text, true, '2026-11-01T12:00:00Z'::timestamptz)$$, :'copied_recipe'),
  'only the rating on the brought recipe remains, with the same content');
select isnt((select id from public.ratings), 'marks-rating-own'::text, 'the copied rating has a new ID');

select tests.clear_auth();
select is((select count(*) from public.user_favorites
  where user_id = :'mover' and recipe_household_id = :'source_household'), 0::bigint,
  'mover favorites on source recipes are removed');
select is((select count(*) from public.ratings r join public.recipes x on x.id = r.recipe_id
  where r.user_id = :'mover' and x.household_id = :'source_household'), 0::bigint,
  'mover ratings on source recipes are removed');
select is((select count(*) from public.deletions where user_id = :'mover' and entity = 'favorite'),
  2::bigint, 'favorite removals sync to the mover''s other devices');
select is((select count(*) from public.deletions where user_id = :'mover' and entity = 'rating'),
  2::bigint, 'rating removals sync to the mover''s other devices');
select is((select count(*) from public.user_favorites where user_id = :'peer'), 1::bigint,
  'peer keeps own favorite on the original recipe');
select is((select count(*) from public.recipes where id in ('marks-own', 'marks-peer')), 2::bigint,
  'original recipes stay in the source household');

-- Leaving without recipes removes all marks and copies nothing.
select tests.authenticate_as(:'stayer');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'stayer' || ':marks-own', 'marks-own', :'source_household', true);
insert into public.ratings (id, recipe_id, stars, cooked_at)
values ('marks-rating-stayer', 'marks-own', 4, '2026-11-03T12:00:00Z');
select is(public.confirm_household_join(:'target_token', :'source_household',
  'leave_recipes', false, gen_random_uuid())->>'status', 'joined', 'stayer joins without recipes');
select is((select count(*) from public.user_favorites), 0::bigint, 'no favorite is carried without recipes');
select is((select count(*) from public.ratings), 0::bigint, 'no rating is carried without recipes');

-- A member removed by the owner loses marks on that household's recipes.
select tests.clear_auth();
select tests.create_user('marks-removed@test.local') as removed \gset
delete from public.household_members where user_id = :'removed';
insert into public.household_members (household_id, user_id, role)
values (:'target_household', :'removed', 'member');
select tests.authenticate_as(:'removed');
insert into public.user_favorites (id, recipe_id, recipe_household_id, is_favorite)
values (:'removed' || ':' || :'copied_recipe', :'copied_recipe', :'target_household', true);
insert into public.ratings (id, recipe_id, stars, cooked_at)
values ('marks-rating-removed', :'copied_recipe', 3, '2026-11-04T12:00:00Z');
select tests.authenticate_as(:'host');
select is(public.remove_household_member(:'removed')->>'status', 'removed', 'owner removes the member');
select tests.authenticate_as(:'removed');
select is((select count(*) from public.user_favorites), 0::bigint, 'removed member loses favorites');
select is((select count(*) from public.ratings), 0::bigint, 'removed member loses ratings');
select tests.authenticate_as(:'mover');
select is((select count(*) from public.user_favorites), 1::bigint, 'remaining member keeps favorites');
select tests.clear_auth();

select * from finish();
rollback;
