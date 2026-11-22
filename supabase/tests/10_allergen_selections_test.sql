begin;
select * from no_plan();

select tests.create_user('allergens-a@test.local') as owner_id \gset
select tests.create_user('allergens-b@test.local') as peer_id \gset
select tests.household_of(:'owner_id') as household_id \gset
delete from public.household_members where user_id = :'peer_id';
insert into public.household_members (household_id, user_id, role)
values (:'household_id', :'peer_id', 'owner');

select tests.authenticate_as(:'owner_id');
select lives_ok($$insert into public.user_allergen_selections (group_codes)
  values (array['milk','nuts'])$$, 'owner saves an allergen selection');
select throws_ok($$update public.user_allergen_selections set group_codes = array['lactose']$$,
  '23514', null, 'unknown code rejected');
select throws_ok($$update public.user_allergen_selections set group_codes = array['milk','milk']$$,
  '23514', null, 'duplicates rejected');
select throws_ok($$update public.user_allergen_selections set group_codes = array['milk',null]$$,
  '23514', null, 'null code rejected');

select tests.authenticate_as(:'peer_id');
select is((select count(*) from public.user_allergen_selections), 0::bigint, 'peer sees no owner row');
select is(tests.affected($$update public.user_allergen_selections set group_codes = '{}'$$),
  0::bigint, 'peer cannot clear owner selection');
select throws_ok(format($$insert into public.user_allergen_selections (user_id) values (%L)$$, :'owner_id'),
  '42501', null, 'peer cannot write as owner');
select lives_ok($$insert into public.user_allergen_selections (group_codes) values (array['soy'])$$,
  'peer saves own selection');

select tests.authenticate_as(:'owner_id');
select is((select group_codes from public.user_allergen_selections), array['milk','nuts'], 'owner sees only own selection');
select lives_ok($$update public.user_allergen_selections set group_codes = '{}'$$, 'owner clears selection');
select tests.authenticate_anon();
select throws_ok($$select * from public.user_allergen_selections$$,
  '42501', null, 'anonymous access denied');

select tests.clear_auth();
delete from auth.users where id = :'owner_id';
select is((select count(*) from public.user_allergen_selections where user_id = :'owner_id'),
  0::bigint, 'account deletion removes selection');
select * from finish();
rollback;
