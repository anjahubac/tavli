-- Brisanje naloga i prelazak koriste isti redosled nasleđivanja.
begin;
select plan(26);

select tests.create_user('departure-owner@test.local') as owner_id \gset
select tests.create_user('departure-first@test.local') as first_id \gset
select tests.create_user('departure-second@test.local') as second_id \gset
select tests.create_user('departure-member@test.local') as member_id \gset
select tests.create_user('departure-target@test.local') as target_id \gset
select tests.household_of(:'owner_id') as home \gset
select tests.household_of(:'first_id') as first_home,
       tests.household_of(:'second_id') as second_home,
       tests.household_of(:'member_id') as member_home \gset
select least(:'first_id'::uuid, :'second_id'::uuid) as successor,
       greatest(:'first_id'::uuid, :'second_id'::uuid) as last_member \gset

select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as invite \gset
select throws_ok(format('select private.depart_household(%L, %L)', :'home', :'owner_id'),
  '42501', null, 'aplikacija ne može neposredno da menja članstvo');
select throws_ok(format('select public.retired_household_photo_paths(%L, %L)', :'owner_id', :'home'),
  '42501', null, 'aplikacija ne može da čita red za čišćenje');
select tests.clear_auth();

select tests.authenticate_as(:'target_id');
select public.household_invite_token() as target_invite \gset
select tests.clear_auth();

select tests.authenticate_as(:'first_id');
select is(public.confirm_household_join(:'invite', :'first_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'prvi član se pridružuje');
select tests.clear_auth();

select tests.authenticate_as(:'second_id');
select is(public.confirm_household_join(:'invite', :'second_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'drugi član se pridružuje');
select tests.clear_auth();

select tests.authenticate_as(:'member_id');
select is(public.confirm_household_join(:'invite', :'member_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'treći član se pridružuje');
select tests.clear_auth();

update public.household_members set joined_at = '2026-01-01T00:00:00Z'
  where user_id in (:'first_id', :'second_id');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('departure-recipe', :'home', 'Zajednički recept', 1, 'manual', '[]', '[]');
insert into storage.objects (bucket_id, name)
  values ('recipe-photos', :'home' || '/legacy/departure-photo.jpg');

set local role service_role;
select lives_ok(format('select public.delete_account_data(%L)', :'member_id'), 'običan član briše nalog');
reset role;
select is(tests.household_of(:'member_id'), null::uuid, 'članstvo obrisanog člana je uklonjeno');
select is((select array_agg(user_id) from public.household_members
  where household_id = :'home' and role = 'owner'), array[:'owner_id'::uuid],
  'brisanje običnog člana zadržava vlasnika');

set local role service_role;
select lives_ok(format('select public.delete_account_data(%L)', :'owner_id'), 'vlasnik briše nalog');
select is_empty(format('select * from public.household_join_photo_cleanup(%L, null)', :'owner_id'),
  'deljene slike nisu zakazane za brisanje');
select lives_ok(format('select public.delete_account_data(%L)', :'owner_id'), 'ponovljeno brisanje vlasnika');
reset role;
select is(tests.household_of(:'owner_id'), null::uuid, 'članstvo obrisanog vlasnika je uklonjeno');
select is((select array_agg(user_id) from public.household_members
  where household_id = :'home' and role = 'owner'), array[:'successor'::uuid],
  'pri istom vremenu pridruživanja nasleđuje manji UUID');

select tests.authenticate_as(:'successor');
select is(public.household_invite_token(), :'invite', 'naslednik preuzima postojeću pozivnicu');
select is((select count(*) from public.recipes where id = 'departure-recipe'),
  1::bigint, 'naslednik vidi zajednički recept');
select is(public.confirm_household_join(:'target_invite', :'home', 'leave_recipes', false,
  gen_random_uuid())->>'status', 'joined', 'naslednik prelazi u drugo domaćinstvo');
select tests.clear_auth();

select tests.authenticate_as(:'last_member');
select is(public.household_invite_token(), :'invite', 'poslednji član preuzima istu pozivnicu');
select is(public.confirm_household_join(:'target_invite', :'home', 'leave_recipes', false,
  gen_random_uuid())->>'status', 'source_deletion_confirmation_required',
  'posle odlaska naslednika poslednji član mora da potvrdi gašenje pri prelasku');
select tests.clear_auth();

set local role service_role;
select lives_ok(format('select public.delete_account_data(%L)', :'last_member'), 'poslednji član briše nalog');
select is(array(select public.household_join_photo_cleanup(:'last_member', null)), array[:'home'::uuid],
  'slika obrisanog domaćinstva ostaje u redu za čišćenje');
select is(array(select public.retired_household_photo_paths(:'last_member', :'home')),
  array[:'home' || '/legacy/departure-photo.jpg'], 'red vraća tačnu putanju stare slike');
select is_empty(format('select * from public.retired_household_photo_paths(%L, %L)', :'owner_id', :'home'),
  'posao čišćenja je vezan za nalog koji ga je napravio');
select is(array(select public.household_join_photo_cleanup(:'last_member', :'home')),
  array[:'home'::uuid], 'potvrda ne uklanja posao dok slika još postoji');
select lives_ok(format('select public.delete_account_data(%L)', :'last_member'), 'ponovljeno brisanje poslednjeg člana');
select is(array(select public.household_join_photo_cleanup(:'last_member', null)), array[:'home'::uuid],
  'ponovljeno brisanje zadržava isti posao čišćenja');
reset role;

select ok(not exists (select 1 from public.households where id = :'home')
  and not exists (select 1 from public.recipes where id = 'departure-recipe')
  and not exists (select 1 from private.household_invites where household_id = :'home'),
  'posle poslednjeg člana brišu se domaćinstvo, recept i pozivnica');

select * from finish();
rollback;
