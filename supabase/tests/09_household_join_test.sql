-- D3-005: direktno pridruživanje preko trajnog linka.
begin;
select no_plan();

select has_function('public', 'household_invite_token', array[]::text[], 'postoji RPC za vlasnikov link');
select has_function('public', 'preview_household_join', array['text'], 'postoji RPC za pregled');
select has_function('public', 'confirm_household_join',
  array['text', 'uuid', 'text', 'boolean', 'uuid'], 'postoji RPC za potvrdu');

select tests.create_user('join-owner@test.local') as owner_id \gset
select tests.create_user('join-older@test.local') as older_id \gset
select tests.create_user('join-newer@test.local') as newer_id \gset
select tests.create_user('join-target@test.local') as target_id \gset
select tests.household_of(:'owner_id') as source_id \gset
select tests.household_of(:'older_id') as older_source_id \gset
select tests.household_of(:'newer_id') as newer_source_id \gset
select tests.household_of(:'target_id') as target_household_id \gset
select gen_random_uuid() as older_operation, gen_random_uuid() as newer_operation,
       gen_random_uuid() as owner_operation \gset

update public.households set name = 'Odredište' where id = :'target_household_id';

select tests.authenticate_as(:'owner_id');
select public.household_invite_token() as source_token \gset
select is(public.household_invite_token(), :'source_token', 'vlasnik dobija isti token pri ponovnom čitanju');
select tests.clear_auth();

select tests.authenticate_as(:'target_id');
select public.household_invite_token() as target_token \gset
select tests.clear_auth();

select tests.authenticate_as(:'older_id');
select public.household_invite_token() as retired_token \gset
select tests.clear_auth();

select tests.authenticate_anon();
select throws_ok('select public.household_invite_token()', '42501', null, 'anon ne čita link');
select throws_ok(format('select public.preview_household_join(%L)', :'source_token'),
  '42501', null, 'anon ne pregleda domaćinstvo');
select throws_ok(format('select public.confirm_household_join(%L, %L, %L, true, %L)',
  :'source_token', :'older_source_id', 'leave_recipes', :'older_operation'),
  '42501', null, 'anon ne može da se pridruži');
select tests.clear_auth();

select tests.authenticate_as(:'older_id');
select is((select count(*) from public.households where id = :'source_id'),
  0::bigint, 'tuđe domaćinstvo je sakriveno pre potvrde');
select is(public.preview_household_join(repeat('0', 64))->>'status',
  'unavailable', 'nevažeći token ne otkriva podatke');
select is(public.preview_household_join(:'source_token')->>'household_name',
  'Moje domaćinstvo', 'važeći token otkriva naziv');
select is(public.preview_household_join(:'source_token')->>'source_household_id',
  :'older_source_id', 'pregled vraća sopstveni izvor');
select is(public.preview_household_join(:'source_token')->>'requires_source_deletion_ack',
  'true', 'poslednji član mora da vidi upozorenje');
select is((select count(*) from public.households where id = :'source_id'),
  0::bigint, 'pregled ne daje pristup redovima odredišta');
select is(public.confirm_household_join(:'source_token', :'older_source_id',
  'leave_recipes', false, :'older_operation')->>'status',
  'source_deletion_confirmation_required', 'bez potvrde nema destruktivnog prelaska');
select is(public.confirm_household_join(:'source_token', :'older_source_id',
  'leave_recipes', null, :'older_operation')->>'status',
  'invalid_request', 'null nije potvrda brisanja');
select is(public.confirm_household_join(:'source_token', null,
  'leave_recipes', true, :'older_operation')->>'status',
  'invalid_request', 'potvrda zahteva očekivani izvor');
select is(tests.household_of(:'older_id'), :'older_source_id'::uuid,
  'odbijena potvrda zadržava članstvo');
select tests.clear_auth();

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('join-solo-recipe', :'older_source_id', 'Recept iz ličnog domaćinstva', 1, 'manual', '[]', '[]');
insert into public.pantry_items (id, household_id, name, category, added_at)
values ('join-solo-pantry', :'older_source_id', 'So', 'ostalo', now());
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types, use_pantry)
values ('join-solo-plan', :'older_source_id', now(), now() + interval '7 days', '[]', false);
insert into public.shopping_lists (id, household_id, name)
values ('join-solo-shopping', :'older_source_id', 'Stara nabavka');

select tests.authenticate_as(:'older_id');
select is(public.confirm_household_join(:'source_token', :'older_source_id',
  'leave_recipes', true, :'older_operation')->>'status',
  'joined', 'potvrda prebacuje člana i dozvoljava brisanje');
select is(public.confirm_household_join(:'source_token', :'older_source_id',
  'leave_recipes', true, :'older_operation')->>'status',
  'joined', 'isti zahtev vraća isti rezultat');
select is(public.confirm_household_join(:'source_token', :'older_source_id',
  'bring_recipes', true, :'older_operation')->>'status',
  'operation_conflict', 'identitet operacije je vezan za originalni izbor');
select is((select count(*) from public.households where id = :'source_id'),
  1::bigint, 'posle potvrde član vidi domaćinstvo');
select throws_ok('select public.household_invite_token()', '42501', null,
  'član bez uloge vlasnika ne čita token');
select tests.clear_auth();

select is((select count(*) from public.households where id = :'older_source_id'),
  0::bigint, 'potvrđeno prazno domaćinstvo je obrisano');
select is((select count(*) from public.recipes where id = 'join-solo-recipe'),
  0::bigint, 'izbor bez recepata briše preostali recept sa praznim izvorom');
select is((select count(*) from public.pantry_items where id = 'join-solo-pantry'),
  0::bigint, 'stara ostava je obrisana');
select is((select count(*) from public.meal_plans where id = 'join-solo-plan'),
  0::bigint, 'stari plan je obrisan');
select is((select count(*) from public.shopping_lists where id = 'join-solo-shopping'),
  0::bigint, 'stara nabavka je obrisana');
select is((select count(*) from public.recipes where household_id = :'source_id'),
  0::bigint, 'izbor bez recepata ne pravi kopiju');

select tests.authenticate_as(:'target_id');
select is(public.preview_household_join(:'retired_token')->>'status',
  'unavailable', 'link obrisanog domaćinstva više ne radi');
select tests.clear_auth();

select tests.authenticate_as(:'newer_id');
select is(public.confirm_household_join(:'source_token', :'newer_source_id',
  'leave_recipes', true, :'newer_operation')->>'status',
  'joined', 'drugi nalog koristi isti link');
select tests.clear_auth();

update public.household_members set joined_at = '2026-01-01T00:00:00Z' where user_id = :'older_id';
update public.household_members set joined_at = '2026-02-01T00:00:00Z' where user_id = :'newer_id';

select tests.authenticate_as(:'owner_id');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('join-owned', :'source_id', 'Moj recept', 2, 'manual', '[]', '[]');
select tests.clear_auth();

select tests.authenticate_as(:'older_id');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('join-other', :'source_id', 'Tuđi recept', 1, 'manual', '[]', '[]');
select tests.clear_auth();

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps, updated_by)
values ('join-legacy', :'source_id', 'Stari recept bez autora', 1, 'manual', '[]', '[]', :'older_id');
insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind)
values ('join-version', :'source_id', 'join-owned', '{}', 'ai');

select tests.authenticate_as(:'owner_id');
select is(public.preview_household_join(:'target_token')->>'requires_source_deletion_ack',
  'false', 'kada drugi članovi ostaju, nema upozorenja o brisanju');
select is(public.confirm_household_join(:'target_token', :'older_source_id',
  'bring_recipes', true, gen_random_uuid())->>'status',
  'stale_source', 'zastareli izvor ne dozvoljava prelazak');
select is(public.confirm_household_join(:'target_token', :'source_id',
  'bring_recipes', false, :'owner_operation')->>'status',
  'joined', 'vlasnik prelazi sa izabranim receptima');
select is(public.confirm_household_join(:'target_token', :'source_id',
  'bring_recipes', false, :'owner_operation')->>'status',
  'joined', 'ponovljena potvrda ne kopira recepte drugi put');
select is((select count(*) from public.recipes where household_id = :'source_id'),
  0::bigint, 'bivši član više ne čita stare recepte');
select tests.clear_auth();

select is((select count(*) from public.household_members where user_id = :'owner_id'),
  1::bigint, 'prelazak ostavlja tačno jedno članstvo');
select is((select role from public.household_members where user_id = :'owner_id'),
  'member', 'korisnik se pridružuje kao član');
select is((select role from public.household_members where user_id = :'older_id'),
  'owner', 'najduži član postaje vlasnik');
select is((select role from public.household_members where user_id = :'newer_id'),
  'member', 'noviji član zadržava ulogu');
select is((select count(*) from public.recipes where household_id = :'source_id'),
  3::bigint, 'originali ostaju u starom domaćinstvu');
select is((select array_agg(title order by title) from public.recipes
  where household_id = :'target_household_id'),
  array['Moj recept', 'Stari recept bez autora'], 'kopira samo sopstvene i recepte bez autora');
select is((select count(*) from public.recipes where household_id = :'target_household_id'
  and id in ('join-owned', 'join-legacy')),
  0::bigint, 'kopije imaju svoje identitete');
select is((select count(*) from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
  where r.household_id = :'target_household_id' and v.household_id = r.household_id
    and r.title = 'Moj recept'),
  1::bigint, 'istorija kopije pokazuje na recept u novom domaćinstvu');

select tests.authenticate_as(:'older_id');
select is(public.household_invite_token(), :'source_token',
  'naslednik može da deli postojeći link');
select is(public.confirm_household_join(:'source_token', :'source_id',
  'bring_recipes', false, gen_random_uuid())->>'status',
  'already_member', 'sopstveni link ne menja članstvo');
select tests.clear_auth();

select tests.create_user('join-solo-copy@test.local') as solo_id \gset
select tests.household_of(:'solo_id') as solo_source_id \gset
select gen_random_uuid() as solo_operation \gset

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('join-solo-copy', :'solo_source_id', 'Ponesi iz praznog izvora', 1, 'manual', '[]', '[]');

select tests.authenticate_as(:'solo_id');
select is(public.confirm_household_join(:'target_token', :'solo_source_id',
  'bring_recipes', false, :'solo_operation')->>'status',
  'source_deletion_confirmation_required', 'opcija sa receptima takođe traži potvrdu brisanja');
select is((select count(*) from public.recipes where id = 'join-solo-copy'),
  1::bigint, 'bez potvrde original ostaje dostupan');
select is(public.confirm_household_join(:'target_token', :'solo_source_id',
  'bring_recipes', true, :'solo_operation')->>'status',
  'joined', 'potvrđena kopija preživljava brisanje praznog izvora');
select tests.clear_auth();

select is((select count(*) from public.households where id = :'solo_source_id'),
  0::bigint, 'prazan izvor je obrisan i kada se kopiraju recepti');
select is((select count(*) from public.recipes where household_id = :'target_household_id'
  and title = 'Ponesi iz praznog izvora' and id <> 'join-solo-copy'),
  1::bigint, 'kopija ostaje u odredištu sa novim identitetom');

select * from finish();
rollback;
