-- Korak "Tvoje domaćinstvo", promena naziva i spisak članova (dva naloga
-- i spoljni nalog za negativne slučajeve).
begin;
select plan(26);

select has_function('public', 'rename_household', array['text'], 'postoji RPC za naziv domaćinstva');
select has_function('public', 'household_members_overview', array[]::text[],
  'postoji RPC za spisak članova');

select tests.create_user('setup-owner@test.local') as owner_id \gset
select tests.create_user('setup-joiner@test.local') as joiner_id \gset
select tests.create_user('setup-outsider@test.local') as outsider_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'joiner_id') as joiner_home \gset
select tests.household_of(:'outsider_id') as outsider_home \gset

update public.profiles set display_name = 'Ana' where id = :'owner_id';
update public.profiles set display_name = 'Marko' where id = :'joiner_id';
update public.profiles set display_name = 'Spolja' where id = :'outsider_id';

select is((select household_setup_done from public.profiles where id = :'owner_id'), false,
  'novi nalog još nije izabrao domaćinstvo');

-- Negativni slučajevi bez prijave i za anon.
select throws_ok('select public.rename_household(''Kuća'')', '42501', null,
  'bez prijave nema promene naziva');
set local role anon;
select throws_ok('select public.rename_household(''Kuća'')', '42501', null,
  'anon ne menja naziv');
select throws_ok('select * from public.household_members_overview()', '42501', null,
  'anon ne čita spisak članova');
reset role;

-- Neispravan naziv ne menja ništa.
select tests.authenticate_as(:'owner_id');
select is(public.rename_household('   ')->>'status', 'invalid_name', 'prazan naziv se odbija');
select is(public.rename_household(repeat('a', 41))->>'status', 'invalid_name',
  'naziv duži od 40 znakova se odbija');
select is(public.rename_household(null)->>'status', 'invalid_name', 'null naziv se odbija');
select tests.clear_auth();
select is((select name from public.households where id = :'home'), 'Moje domaćinstvo',
  'naziv ostaje podrazumevani');
select is((select household_setup_done from public.profiles where id = :'owner_id'), false,
  'odbijen naziv ne završava korak');

-- Vlasnik imenuje domaćinstvo i završava korak.
select tests.authenticate_as(:'owner_id');
select is(public.rename_household('  Domaćinstvo Horvat  ')->>'status', 'renamed',
  'vlasnik menja naziv');
select is((select name from public.households where id = :'home'), 'Domaćinstvo Horvat',
  'naziv je sačuvan bez razmaka na krajevima');
select tests.clear_auth();
select is((select household_setup_done from public.profiles where id = :'owner_id'), true,
  'naziv završava korak');

-- Pridruživanje završava korak bez promene naziva.
select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as invite \gset
select tests.clear_auth();
select tests.authenticate_as(:'joiner_id');
select is(public.confirm_household_join(:'invite', :'joiner_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'novi nalog se pridružuje');
select tests.clear_auth();
select is((select household_setup_done from public.profiles where id = :'joiner_id'), true,
  'pridruživanje završava korak');
-- U jednoj transakciji oba članstva imaju isto vreme; redosled pridruživanja
-- se zato zadaje eksplicitno.
update public.household_members set joined_at = joined_at + interval '1 second'
  where user_id = :'joiner_id';

-- Član ne menja naziv; spoljni vlasnik ne menja tuđe domaćinstvo.
select tests.authenticate_as(:'joiner_id');
select is(public.rename_household('Preuzeto')->>'status', 'not_allowed', 'član ne menja naziv');
select tests.clear_auth();
select tests.authenticate_as(:'outsider_id');
select is(public.rename_household('Spoljno')->>'status', 'renamed',
  'spoljni vlasnik menja samo svoje domaćinstvo');
select tests.clear_auth();
select is((select name from public.households where id = :'home'), 'Domaćinstvo Horvat',
  'tuđe domaćinstvo ostaje netaknuto');
select is((select name from public.households where id = :'outsider_home'), 'Spoljno',
  'spoljni vlasnik je promenio svoje domaćinstvo');

-- Direktna izmena tabele i dalje nije dozvoljena.
select tests.authenticate_as(:'owner_id');
select throws_ok(format('update public.households set name = %L where id = %L',
  'Zaobilazno', :'home'), '42501', null, 'nema direktne izmene naziva preko tabele');
select throws_ok(format('update public.profiles set household_setup_done = false where id = %L',
  :'owner_id'), '42501', null, 'nalog ne menja oznaku koraka direktno');

-- Spisak članova: samo sopstveno domaćinstvo, ime i uloga.
select results_eq(
  'select display_name, role from public.household_members_overview()',
  $$values ('Ana'::text, 'owner'::text), ('Marko'::text, 'member'::text)$$,
  'vlasnik vidi sebe i člana, redom pridruživanja');
select tests.clear_auth();

select tests.authenticate_as(:'joiner_id');
select is((select count(*)::int from public.household_members_overview()), 2,
  'član vidi isti spisak');
select tests.clear_auth();

select tests.authenticate_as(:'outsider_id');
select results_eq(
  'select display_name, role from public.household_members_overview()',
  $$values ('Spolja'::text, 'owner'::text)$$,
  'spoljni nalog vidi samo svoje domaćinstvo');
select is((select count(*)::int from public.profiles where id = :'owner_id'), 0,
  'tuđi profil i dalje nije čitljiv');
select tests.clear_auth();

select * from finish();
rollback;
