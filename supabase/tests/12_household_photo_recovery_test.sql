begin;
select no_plan();
-- The fixtures insert metadata only. Simulate the metadata removal that the
-- real worker performs through the Storage API.
set local storage.allow_delete_query = 'true';

select tests.create_user('cleanup-source@test.local') as source_user \gset
select tests.create_user('cleanup-target@test.local') as target_user \gset
select tests.household_of(:'source_user') as source_home \gset
select tests.household_of(:'target_user') as target_home \gset
select gen_random_uuid() as operation \gset

select tests.authenticate_as(:'target_user');
select public.household_invite_token() as code \gset
select tests.clear_auth();

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps, image_path)
values ('cleanup-photo-recipe', :'source_home', 'Recept', 1, 'manual', '[]', '[]', 'origin.jpg');
insert into storage.objects (bucket_id, name, version, metadata)
values ('recipe-photos', :'source_home' || '/origin.jpg', 'original-v1',
  '{"size":7,"eTag":"test-etag"}');

select tests.authenticate_as(:'source_user');
select throws_ok('select public.claim_household_photo_cleanup()', '42501', null,
  'klijent ne može da traži putanje drugih domaćinstava');
select throws_ok('select public.complete_household_photo_cleanup()', '42501', null,
  'klijent ne može da ukloni posao iz reda');
select tests.clear_auth();

set local role service_role;
select (public.prepare_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation')->'photos') as photos \gset
select (:'photos'::jsonb->0->>'destination') as copied_path \gset
select is(public.prepare_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation')->'photos', :'photos'::jsonb,
  'isti operation ID koristi istu rezervaciju za ponovni pokušaj');
reset role;

insert into storage.objects (bucket_id, name, metadata)
values ('recipe-photos', :'copied_path', '{"size":7,"eTag":"test-etag"}');

set local role service_role;
select is(public.claim_household_photo_cleanup()->'staged_paths', '[]'::jsonb,
  'radnik ne čisti aktivnu rezervaciju');
reset role;

update private.household_join_staged_photos
  set expires_at = now() - interval '1 second' where name = :'copied_path';
set local role service_role;
select public.claim_household_photo_cleanup() as abandoned \gset
select is(:'abandoned'::jsonb->'staged_paths', jsonb_build_array(:'copied_path'::text),
  'radnik sam nalazi napuštenu kopiju');
select is(public.prepare_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation')->>'status', 'photo_transfer_retry',
  'ponovni prelazak čeka dok radnik briše istu putanju');
select is(public.finish_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation', :'photos')->>'status', 'photo_transfer_retry',
  'potvrda ne može da objavi kopiju u toku brisanja');
select public.complete_household_photo_cleanup((:'abandoned'::jsonb->>'claim_id')::uuid, null);
reset role;
select ok(exists(select 1 from private.household_join_staged_photos where name = :'copied_path'),
  'greška u Storage-u ostavlja rezervaciju za sledeći pokušaj');

-- Imitira drugu invokaciju nakon isteka lease-a, pa uspešan Storage API poziv.
update private.household_join_staged_photos
  set cleanup_after = now() - interval '1 second' where name = :'copied_path';
set local role service_role;
select public.claim_household_photo_cleanup() as reclaimed \gset
select is(:'reclaimed'::jsonb->'staged_paths', jsonb_build_array(:'copied_path'::text),
  'istekla obrada se ponavlja bez sesije korisnika');
reset role;
delete from storage.objects where name = :'copied_path';
set local role service_role;
select public.complete_household_photo_cleanup((:'abandoned'::jsonb->>'claim_id')::uuid, null);
reset role;
select ok(exists(select 1 from private.household_join_staged_photos where name = :'copied_path'),
  'zakašnjela potvrda prve invokacije ne oslobađa novu rezervaciju');
set local role service_role;
select public.complete_household_photo_cleanup((:'reclaimed'::jsonb->>'claim_id')::uuid, null);
select is(public.prepare_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation')->'photos', :'photos'::jsonb,
  'isti operation ID može ponovo da pripremi kopiju nakon čišćenja');
reset role;

insert into storage.objects (bucket_id, name, metadata)
values ('recipe-photos', :'copied_path', '{"size":7,"eTag":"test-etag"}');
set local role service_role;
select is(public.finish_household_join_photos(:'source_user', :'code', :'source_home',
  'bring_recipes', true, :'operation', :'photos')->>'status', 'joined', 'prelazak je upisan');
select public.claim_household_photo_cleanup() as retired \gset
select is(:'retired'::jsonb->>'retired_id', :'source_home',
  'ugašeno domaćinstvo se čisti nakon upisanog prelaska');
select is(:'retired'::jsonb->'staged_paths', '[]'::jsonb, 'objavljena kopija se ne briše');
select public.complete_household_photo_cleanup(null, :'source_home');
reset role;
select ok(exists(select 1 from private.household_join_photo_cleanup where household_id = :'source_home'),
  'Storage greška nakon commit-a ostavlja ugašeno domaćinstvo u redu');
update private.household_join_photo_cleanup
  set retry_at = now() - interval '1 second', user_id = null where household_id = :'source_home';
set local role service_role;
select is(public.claim_household_photo_cleanup()->'retired_paths',
  jsonb_build_array((:'source_home' || '/origin.jpg')::text),
  'radnik ponavlja obradu bez novog prelaska ili zavisnosti od naloga');
reset role;
delete from storage.objects where name = :'source_home' || '/origin.jpg';
set local role service_role;
select public.complete_household_photo_cleanup(null, :'source_home');
reset role;
select ok(not exists(select 1 from private.household_join_photo_cleanup where household_id = :'source_home'),
  'brisanje potvrđeno tek kada nema preostalih fajlova');
select ok(exists(select 1 from storage.objects where name = :'copied_path'),
  'fotografija odredišta ostaje sačuvana');

select * from finish();
rollback;
