-- Obaveštenje o uklanjanju se pravi samo kad vlasnik ukloni člana, ne kad
-- član sam pređe u novo domaćinstvo.
begin;
select plan(9);

select tests.create_user('notice-owner@test.local') as owner_id \gset
select tests.create_user('notice-member@test.local') as member_id \gset
select tests.create_user('notice-mover@test.local') as mover_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'member_id') as member_home,
       tests.household_of(:'mover_id') as mover_home \gset

select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as invite \gset
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.confirm_household_join(:'invite', :'member_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'član se pridružuje');
select tests.clear_auth();

-- Sopstveni prelazak u novo domaćinstvo: vlasnik, ali bez zapisa o uklanjanju.
select tests.authenticate_as(:'mover_id');
select public.prepare_new_household('Moje novo') as new_token \gset
select is(public.take_household_removal(:'mover_home'), false,
  'sopstveni prelazak ne pravi obaveštenje');
select tests.clear_auth();

select tests.authenticate_as(:'owner_id');
select is(public.remove_household_member(:'member_id')->>'status', 'removed', 'vlasnik uklanja člana');
select is(public.take_household_removal(:'home'), false, 'vlasnik nema tuđi zapis');
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.take_household_removal(gen_random_uuid()), false,
  'zapis se ne poklapa sa drugim domaćinstvom');
select is(public.take_household_removal(:'home'), true, 'uklonjeni preuzima zapis');
select is(public.take_household_removal(:'home'), false, 'zapis se troši, obaveštenje je jednokratno');
select tests.clear_auth();

select ok(not has_table_privilege('authenticated', 'private.household_removals', 'select'),
  'tabela zapisa nije dostupna kroz API');
set local role anon;
select throws_ok(format('select public.take_household_removal(%L)', :'home'),
  '42501', null, 'anon ne preuzima zapise');
reset role;

select * from finish();
rollback;
