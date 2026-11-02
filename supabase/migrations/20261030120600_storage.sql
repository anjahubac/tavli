-- 006a: privatne slike recepata. Putanja objekta: {household_id}/{fajl}.jpg.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-photos', 'recipe-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Prvi deo putanje mora biti id domaćinstva čiji je korisnik član.
-- CASE: neispravan uuid daje false umesto greške.
create policy "recipe-photos: members select" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recipe-photos'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
create policy "recipe-photos: members insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recipe-photos'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
create policy "recipe-photos: members update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'recipe-photos'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  )
  with check (
    bucket_id = 'recipe-photos'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
create policy "recipe-photos: members delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recipe-photos'
    and private.is_member(case
      when (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then ((storage.foldername(name))[1])::uuid end)
  );
