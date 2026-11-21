begin;
select plan(7);

select tests.create_user('rating-a@test.local') as ua \gset
select tests.create_user('rating-b@test.local') as ub \gset
select tests.create_user('rating-outside@test.local') as outsider \gset
select tests.household_of(:'ua') as hid \gset

delete from public.household_members where user_id = :'ub';
insert into public.household_members (household_id, user_id)
values (:'hid', :'ub');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('rated', :'hid', 't', 1, 'manual', '[]', '[]');

select tests.authenticate_as(:'ua');
insert into public.ratings (id, recipe_id, stars, comment, cooked_at)
values ('rating-a', 'rated', 1, 'private note', now());
insert into public.ratings (id, recipe_id, stars, comment, cooked_at)
values ('rating-second-device', 'rated', 3, 'updated private note', now())
on conflict (user_id, recipe_id) do update
set id = excluded.id, stars = excluded.stars, comment = excluded.comment;
select is((select id from public.ratings), 'rating-a', 'upsert keeps the canonical ID');
select is((select comment from public.ratings), 'updated private note', 'author can read their note');

select tests.authenticate_as(:'ub');
select is((select count(*) from public.ratings), 0::bigint, 'co-member cannot read personal ratings or notes');
insert into public.ratings (id, recipe_id, stars, cooked_at)
values ('rating-b', 'rated', 5, now());
select is((select average_stars from public.get_household_recipe_rating_summaries()), 4.0::numeric, 'member can read the average');
select is((select rating_count from public.get_household_recipe_rating_summaries()), 2::bigint, 'one rating counts per member');

select tests.authenticate_as(:'outsider');
select is((select count(*) from public.get_household_recipe_rating_summaries()), 0::bigint, 'outsider gets no summary');
select ok(not has_function_privilege('anon', 'public.get_household_recipe_rating_summaries()', 'execute'), 'anon cannot call summary');

select * from finish();
rollback;
