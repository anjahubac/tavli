-- Vlasnik uklanja člana; svaki nalog uvek ima tačno jedno domaćinstvo.
begin;
select plan(21);

select has_function('public', 'remove_household_member', array['uuid'], 'postoji RPC za uklanjanje člana');

select tests.create_user('removal-owner@test.local') as owner_id \gset
select tests.create_user('removal-member@test.local') as member_id \gset
select tests.create_user('removal-other@test.local') as other_id \gset
select tests.create_user('removal-outsider@test.local') as outsider_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'member_id') as member_home,
       tests.household_of(:'other_id') as other_home,
       tests.household_of(:'outsider_id') as outsider_home \gset

select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as invite \gset
select tests.clear_auth();
select tests.authenticate_as(:'outsider_id');
select public.household_invite_token() as outsider_invite \gset
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.confirm_household_join(:'invite', :'member_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'član se pridružuje');
select tests.clear_auth();
select tests.authenticate_as(:'other_id');
select is(public.confirm_household_join(:'invite', :'other_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'drugi član se pridružuje');
select tests.clear_auth();

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('removal-recipe', :'home', 'Zajednički recept', 1, 'manual', '[]', '[]');

-- Negativni slučajevi: ništa se ne menja.
select throws_ok(format('select public.remove_household_member(%L)', :'member_id'),
  '42501', null, 'bez prijave nema uklanjanja');

set local role anon;
select throws_ok(format('select public.remove_household_member(%L)', :'member_id'),
  '42501', null, 'anon ne izvršava uklanjanje');
reset role;

select tests.authenticate_as(:'other_id');
select is(public.remove_household_member(:'member_id')->>'status', 'not_allowed',
  'običan član ne uklanja drugog člana');
select tests.clear_auth();

select tests.authenticate_as(:'outsider_id');
select is(public.remove_household_member(:'member_id')->>'status', 'not_allowed',
  'vlasnik drugog domaćinstva ne uklanja tuđeg člana');
select tests.clear_auth();

select tests.authenticate_as(:'owner_id');
select is(public.remove_household_member(:'owner_id')->>'status', 'invalid_request',
  'vlasnik ne uklanja sebe');
select is(public.remove_household_member(:'outsider_id')->>'status', 'not_allowed',
  'vlasnik ne uklanja nekoga ko nije u njegovom domaćinstvu');
select is(tests.household_of(:'outsider_id'), :'outsider_home'::uuid,
  'tuđe članstvo ostaje netaknuto');
select is(tests.household_of(:'member_id'), :'home'::uuid, 'član je još u domaćinstvu');

-- Uklanjanje.
select is(public.remove_household_member(:'member_id')->>'status', 'removed', 'vlasnik uklanja člana');
select is(public.remove_household_member(:'member_id')->>'status', 'not_allowed',
  'ponovljeno uklanjanje ne menja ništa');
select tests.clear_auth();

select isnt(tests.household_of(:'member_id'), :'home'::uuid, 'uklonjeni više nije u starom domaćinstvu');
select is((select role from public.household_members where user_id = :'member_id'), 'owner',
  'uklonjeni je vlasnik novog ličnog domaćinstva');
select is((select count(*)::int from public.household_members where household_id = :'home'), 2,
  'vlasnik i drugi član ostaju');

select tests.authenticate_as(:'member_id');
select is((select count(*)::int from public.recipes where household_id = :'home'), 0,
  'uklonjeni ne čita stare recepte');
select is(public.confirm_household_join(:'outsider_invite', tests.household_of(:'member_id'),
  'leave_recipes', true, gen_random_uuid())->>'status', 'joined',
  'uklonjeni može da pređe u drugo domaćinstvo');
select tests.clear_auth();

-- Novi nalog prolazi proveru (okidač na profiles).
savepoint signup;
select tests.create_user('removal-new@test.local') as new_id \gset
select lives_ok('set constraints all immediate', 'novi nalog dobija domaćinstvo i prolazi proveru');
rollback to savepoint signup;
-- SET CONSTRAINTS ne poništava rollback to savepoint.
set constraints all deferred;

-- Server odbija transakciju koja ostavi nalog bez domaćinstva.
savepoint orphan;
delete from public.household_members where user_id = :'other_id';
select throws_ok('set constraints all immediate', '23514', null,
  'nalog ne sme ostati bez domaćinstva');
rollback to savepoint orphan;

set local role service_role;
select public.delete_account_data(:'other_id');
reset role;
select lives_ok('set constraints all immediate',
  'prelazi i brisanje naloga prolaze proveru članstva');

select * from finish();
rollback;
