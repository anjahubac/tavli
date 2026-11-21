begin;
select no_plan();

select tests.create_user('invite-photo-owner@test.local') as source_user \gset
select tests.create_user('invite-photo-target@test.local') as target_user \gset
select tests.household_of(:'source_user') as source_home \gset
select tests.household_of(:'target_user') as target_home \gset
select gen_random_uuid() as operation \gset

select tests.authenticate_as(:'target_user');
select public.household_invite_token() as code \gset
select ok(:'code' ~ '^[0-9A-HJKMNP-TV-Z]{12}$', 'novi poziv koristi 12 znakova');
select lower(regexp_replace(:'code', '(.{4})(?=.)', '\1-', 'g')) as grouped \gset
select tests.clear_auth();

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps, image_path)
values ('source-photo-recipe', :'source_home', 'Recept za prenos', 1, 'manual', '[]', '[]', 'origin.jpg');
insert into public.recipe_versions (id, household_id, recipe_id, recipe_json, change_kind)
values ('source-photo-version', :'source_home', 'source-photo-recipe',
  '{"id":"source-photo-recipe","imagePath":"recipe_photos/origin.jpg"}', 'ai');
insert into storage.objects (bucket_id, name, version, metadata)
values ('recipe-photos', :'source_home' || '/origin.jpg', 'original-v1',
  '{"size":7,"eTag":"test-etag"}');

select tests.authenticate_as(:'source_user');
select is(public.preview_household_join(:'grouped')->>'status', 'available',
  'pregled prihvata mala slova i crtice');
select is(public.confirm_household_join(:'grouped', :'source_home', 'bring_recipes', true, :'operation')->>'status',
  'photo_transfer_pending', 'običan RPC ne zaobilazi prenos privatnih objekata');
select throws_ok(format('select public.prepare_household_join_photos(%L,%L,%L,%L,true,%L)',
  :'source_user', :'grouped', :'source_home', 'bring_recipes', :'operation'),
  '42501', null, 'klijent nema pristup manifestu');
select tests.clear_auth();

set local role service_role;
select (public.prepare_household_join_photos(:'source_user', :'grouped', :'source_home',
  'bring_recipes', true, :'operation')->'photos') as photos \gset
select (:'photos'::jsonb->0->>'destination') as copied_path \gset
select is(public.finish_household_join_photos(:'source_user', :'grouped', :'source_home',
  'bring_recipes', true, :'operation', :'photos')->>'status', 'photo_transfer_retry',
  'nedostajuća kopija prekida potvrdu');
reset role;

select is(tests.household_of(:'source_user'), :'source_home'::uuid,
  'posle neuspeha članstvo i izvor ostaju dostupni');
insert into storage.objects (bucket_id, name, metadata)
values ('recipe-photos', :'copied_path', '{"size":7,"eTag":"test-etag"}');

select tests.authenticate_as(:'target_user');
select is((select count(*) from storage.objects where name = :'copied_path'),
  0::bigint, 'član odredišta ne vidi pripremljenu kopiju');
select tests.clear_auth();

set local role service_role;
select is(public.finish_household_join_photos(:'source_user', :'grouped', :'source_home',
  'bring_recipes', true, :'operation', :'photos')->>'status', 'joined',
  'potvrđena kopija omogućava prelazak');
select is(array(select public.household_join_photo_cleanup(:'source_user', null)),
  array[:'source_home'::uuid], 'brisanje privatnih fajlova čeka u trajnom redu');
reset role;

select tests.authenticate_as(:'target_user');
select is((select count(*) from storage.objects where name = :'copied_path'),
  1::bigint, 'kopija je dostupna posle prelaska');
select is((select created_by from public.recipes where household_id = :'target_home'),
  :'source_user'::uuid, 'kopija sa slikom pripada osobi koja je donela recept');
select is((select image_path from public.recipes where household_id = :'target_home'),
  split_part(:'copied_path', '/', 2), 'recept koristi putanju kopije');
select is((select recipe_json->>'imagePath' from public.recipe_versions where household_id = :'target_home'),
  'recipe_photos/' || split_part(:'copied_path', '/', 2), 'istorija koristi istu kopiju');
select tests.clear_auth();

select * from finish();
rollback;
