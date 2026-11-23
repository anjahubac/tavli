-- Deljenje pozivnice (svaki član) i nova pozivnica (samo vlasnik), sa
-- spoljnim nalogom i anon za negativne slučajeve.
begin;
select plan(17);

select has_function('public', 'regenerate_household_invite', array[]::text[],
  'postoji RPC za novu pozivnicu');

select tests.create_user('invite-owner@test.local') as owner_id \gset
select tests.create_user('invite-member@test.local') as member_id \gset
select tests.create_user('invite-outsider@test.local') as outsider_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'member_id') as member_home \gset

select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as old_token \gset
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.confirm_household_join(:'old_token', :'member_home',
  'leave_recipes', true, gen_random_uuid())->>'status', 'joined',
  'član se pridružuje starom pozivnicom');
select is(public.household_invite_token(), :'old_token',
  'član deli istu pozivnicu kao vlasnik');
select throws_ok('select public.regenerate_household_invite()', '42501', null,
  'član ne pravi novu pozivnicu');
select is(public.household_invite_token(), :'old_token',
  'odbijen pokušaj člana ne menja pozivnicu');
select tests.clear_auth();

select throws_ok('select public.regenerate_household_invite()', '42501', null,
  'bez prijave nema nove pozivnice');
set local role anon;
select throws_ok('select public.regenerate_household_invite()', '42501', null,
  'anon ne pravi novu pozivnicu');
reset role;

select tests.authenticate_as(:'owner_id');
select public.regenerate_household_invite() as new_token \gset
select isnt(:'new_token'::text, :'old_token'::text, 'vlasnik dobija drugačiji kod');
select ok(:'new_token' ~ '^[0-9A-HJKMNP-TV-Z]{12}$', 'novi kod ima 12 znakova');
select is(public.household_invite_token(), :'new_token',
  'deljenje posle zamene vraća novi kod');
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.household_invite_token(), :'new_token', 'član vidi novi kod');
select tests.clear_auth();

select tests.authenticate_as(:'outsider_id');
select isnt(public.regenerate_household_invite(), :'new_token',
  'vlasnik drugog domaćinstva menja samo svoju pozivnicu');
select is(public.preview_household_join(:'old_token')->>'status', 'unavailable',
  'stari kod više ne radi');
select is(public.preview_household_join(:'new_token')->>'household_name',
  'Moje domaćinstvo', 'novi kod radi');
select tests.clear_auth();

select tests.authenticate_as(:'owner_id');
select is(public.household_invite_token(), :'new_token',
  'tuđa zamena ne menja pozivnicu ovog domaćinstva');
select tests.clear_auth();

select is((select count(*) from public.household_members where household_id = :'home'),
  2::bigint, 'zamena pozivnice ne uklanja članove');
select is((select count(*) from private.household_invites where household_id = :'home'),
  1::bigint, 'domaćinstvo i dalje ima jednu pozivnicu');

select * from finish();
rollback;
