-- "Kreiraj novo domaćinstvo": prazno domaćinstvo sa kodom, prelazak istim
-- tokom kao pridruživanje, vlasništvo i čišćenje napuštenih pokušaja.
begin;
select plan(27);

select has_function('public', 'prepare_new_household', array['text'],
  'postoji RPC za novo domaćinstvo');

select tests.create_user('new-owner@test.local') as owner_id \gset
select tests.create_user('new-member@test.local') as member_id \gset
select tests.create_user('new-outsider@test.local') as outsider_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'member_id') as member_home \gset

-- Negativni slučajevi bez prijave i za anon.
select throws_ok('select public.prepare_new_household(''Vikendica'')', '42501', null,
  'bez prijave nema novog domaćinstva');
set local role anon;
select throws_ok('select public.prepare_new_household(''Vikendica'')', '42501', null,
  'anon ne pravi domaćinstvo');
reset role;

-- Neispravan naziv ne pravi ništa.
select tests.authenticate_as(:'owner_id');
select is(public.prepare_new_household('   ')->>'status', 'invalid_name', 'prazan naziv se odbija');
select is(public.prepare_new_household(repeat('a', 41))->>'status', 'invalid_name',
  'predug naziv se odbija');
select tests.clear_auth();
select is((select count(*)::int from private.pending_new_households), 0,
  'odbijen naziv ne pravi domaćinstvo');

-- Ponovljen pokušaj briše prethodno prazno domaćinstvo.
select tests.authenticate_as(:'owner_id');
select public.prepare_new_household('Prvi pokušaj')->>'token' as first_token \gset
select tests.clear_auth();
select household_id as first_new from private.pending_new_households
  where user_id = :'owner_id' \gset
select tests.authenticate_as(:'owner_id');
select is(public.prepare_new_household('  Vikendica  ')->>'status', 'ready', 'novo domaćinstvo je spremno');
select tests.clear_auth();
select is((select count(*)::int from public.households where id = :'first_new'), 0,
  'napušteno prazno domaćinstvo je obrisano');
select household_id as new_home from private.pending_new_households
  where user_id = :'owner_id' \gset
select token as new_token from private.household_invites where household_id = :'new_home' \gset
select is((select name from public.households where id = :'new_home'), 'Vikendica',
  'naziv je sačuvan bez razmaka na krajevima');

-- Prazno domaćinstvo nije vidljivo ni vlasniku pre prelaska.
select tests.authenticate_as(:'owner_id');
select is((select count(*)::int from public.households where id = :'new_home'), 0,
  'domaćinstvo bez članova nije čitljivo');
select is(public.preview_household_join(:'new_token')->>'household_name', 'Vikendica',
  'pregled pokazuje naziv novog domaćinstva');
select tests.clear_auth();

-- Drugi nalog sa istim kodom ne ulazi pre osobe koja ga je napravila.
select tests.authenticate_as(:'outsider_id');
select tests.household_of(:'outsider_id') as outsider_home \gset
select throws_ok(format('select public.confirm_household_join(%L, %L, %L, true, gen_random_uuid())',
  :'new_token', :'outsider_home', 'leave_recipes'), '42501', null,
  'tuđ nalog ne ulazi u novo domaćinstvo');
select tests.clear_auth();
select is(tests.household_of(:'outsider_id'), :'outsider_home'::uuid,
  'tuđ nalog ostaje u svom domaćinstvu');

-- Član koji odlazi: staro domaćinstvo ostaje drugima.
select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as old_invite \gset
select tests.clear_auth();
select tests.authenticate_as(:'member_id');
select is(public.confirm_household_join(:'old_invite', :'member_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'drugi nalog se pridružuje starom domaćinstvu');
select tests.clear_auth();

select tests.authenticate_as(:'owner_id');
select is(public.confirm_household_join(:'new_token', :'home', 'leave_recipes', false,
  gen_random_uuid())->>'status', 'joined', 'vlasnik prelazi u novo domaćinstvo');
select tests.clear_auth();
select is(tests.household_of(:'owner_id'), :'new_home'::uuid, 'nalog je u novom domaćinstvu');
select is((select role from public.household_members where user_id = :'owner_id'), 'owner',
  'prvi član novog domaćinstva je vlasnik');
select is((select count(*)::int from private.pending_new_households where user_id = :'owner_id'), 0,
  'novo domaćinstvo više nije na čekanju');
select is((select count(*)::int from public.households where id = :'home'), 1,
  'staro domaćinstvo ostaje drugom članu');
select is((select role from public.household_members where user_id = :'member_id'), 'owner',
  'preostali član preuzima vlasništvo');

-- Brisanje naloga briše i nekorišćeno prazno domaćinstvo.
select tests.authenticate_as(:'outsider_id');
select public.prepare_new_household('Ostavljeno')->>'status' as ignored \gset
select tests.clear_auth();
select household_id as abandoned from private.pending_new_households
  where user_id = :'outsider_id' \gset
delete from auth.users where id = :'outsider_id';
select is((select count(*)::int from public.households where id = :'abandoned'), 0,
  'brisanje naloga briše prazno domaćinstvo');

select tests.authenticate_as(:'owner_id');
select is(public.rename_household('Vikendica 2')->>'status', 'renamed',
  'vlasnik novog domaćinstva menja naziv');
select tests.clear_auth();

-- Napušteno prazno domaćinstvo se briše tek posle jednog dana.
select tests.create_user('new-abandon@test.local') as abandon_id \gset
select tests.authenticate_as(:'abandon_id');
select public.prepare_new_household('Napušteno') as abandoned \gset
select tests.clear_auth();
select household_id as abandoned_home from private.pending_new_households
  where user_id = :'abandon_id' \gset
select is(private.purge_stale_new_households(), 0, 'svež pokušaj se ne briše');
update private.pending_new_households set created_at = now() - interval '25 hours'
  where user_id = :'abandon_id';
select is(private.purge_stale_new_households(), 1, 'stari pokušaj se briše');
select is((select count(*)::int from public.households where id = :'abandoned_home'), 0,
  'briše se i prazno domaćinstvo');
select is(private.purge_stale_new_households(), 0, 'ponovljeno pokretanje ne menja ništa');
select is((select count(*)::int from cron.job where jobname = 'stale-new-households'), 1,
  'čišćenje je zakazano');

select * from finish();
rollback;
