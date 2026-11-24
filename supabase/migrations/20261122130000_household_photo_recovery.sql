-- A staged copy is private until the join commits. Its name remains reserved
-- while the cleanup worker is deleting it, so a retry cannot publish it mid-delete.
create table private.household_join_staged_photos (
  name text primary key,
  expires_at timestamptz not null,
  cleanup_after timestamptz,
  cleanup_claim uuid
);
alter table private.household_join_staged_photos enable row level security;
revoke all on private.household_join_staged_photos
  from public, anon, authenticated, service_role;
create index household_join_staged_photos_due
  on private.household_join_staged_photos (coalesce(cleanup_after, expires_at));

insert into private.household_join_staged_photos (name, expires_at)
select o.name, now() + interval '24 hours' from storage.objects o
where o.bucket_id = 'recipe-photos'
  and o.name ~ '^[0-9a-f-]{36}/joinphoto-[0-9a-f]{64}\.jpg$'
  and not exists (
    select 1 from private.household_join_published_photos p where p.name = o.name
  );

alter table private.household_join_photo_cleanup
  add column retry_at timestamptz not null default now();

alter function public.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  set schema private;
revoke all on function private.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  from service_role;

create function public.prepare_household_join_photos(
  caller_id uuid, token text, source_id uuid, recipe_choice text,
  source_deletion_ack boolean, operation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  manifest jsonb;
  photo_name text;
begin
  perform pg_advisory_xact_lock(hashtextextended(caller_id::text, 0));
  manifest := private.prepare_household_join_photos(
    caller_id, token, source_id, recipe_choice, source_deletion_ack, operation_id
  );
  if manifest->>'status' <> 'ready' then return manifest; end if;

  for photo_name in
    select p->>'destination' from jsonb_array_elements(manifest->'photos') p order by 1
  loop
    insert into private.household_join_staged_photos (name, expires_at)
      values (photo_name, now() + interval '24 hours')
    on conflict (name) do update set expires_at = excluded.expires_at
      where household_join_staged_photos.cleanup_claim is null;
    if not found then return jsonb_build_object('status', 'photo_transfer_retry'); end if;
  end loop;
  return manifest;
end;
$$;
revoke all on function public.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  to service_role;

create or replace function private.apply_household_join(
  token text,
  expected_source_household_id uuid,
  recipe_choice text,
  source_deletion_ack boolean,
  operation_id uuid,
  uid uuid,
  approved_photos jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_id uuid;
  source_id uuid;
  source_count bigint;
  request_hash text;
  prior private.household_join_operations%rowtype;
  result jsonb;
  recipe public.recipes%rowtype;
  copied_id text;
  photos jsonb := '[]'::jsonb;
  staged_count bigint;
  mapped_photos jsonb := '{}'::jsonb;
begin
  if uid is null then raise insufficient_privilege; end if;
  if recipe_choice is null or recipe_choice not in ('bring_recipes', 'leave_recipes')
     or operation_id is null or expected_source_household_id is null
     or source_deletion_ack is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;
  if token is null then
    return jsonb_build_object('status', 'unavailable');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  request_hash := encode(extensions.digest(
    token || ':' || expected_source_household_id::text || ':' || recipe_choice || ':' || source_deletion_ack::text,
    'sha256'), 'hex');
  select * into prior from private.household_join_operations o
   where o.user_id = uid and o.operation_id = apply_household_join.operation_id;
  if found then
    if prior.request_hash <> request_hash then return jsonb_build_object('status', 'operation_conflict'); end if;
    if not exists (
      select 1 from public.household_members m where m.user_id = uid
        and m.household_id = (prior.result->>'household_id')::uuid
    ) then
      return jsonb_build_object('status', 'stale_source');
    end if;
    return prior.result;
  end if;
  select i.household_id into target_id from private.household_invites i
   where i.token = apply_household_join.token;
  if target_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  perform 1 from public.households h
    where h.id in (expected_source_household_id, target_id)
    order by h.id for update;
  if not exists (select 1 from public.households h where h.id = target_id) then
    return jsonb_build_object('status', 'unavailable');
  end if;
  select m.household_id into source_id from public.household_members m
   where m.user_id = uid for update;
  if source_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  if source_id = target_id then return jsonb_build_object('status', 'already_member'); end if;
  if source_id <> expected_source_household_id then return jsonb_build_object('status', 'stale_source'); end if;
  select count(*) into source_count from public.household_members m where m.household_id = source_id;
  if source_count = 1 and not source_deletion_ack then
    return jsonb_build_object('status', 'source_deletion_confirmation_required');
  end if;

  if recipe_choice = 'bring_recipes' then
    photos := private.household_join_photo_manifest(source_id, target_id, uid, operation_id);
  end if;
  if approved_photos is null and (jsonb_array_length(photos) > 0 or
    (source_count = 1 and exists (
      select 1 from storage.objects o where o.bucket_id = 'recipe-photos'
        and o.name like source_id::text || '/%'
    ))
  ) then
    return jsonb_build_object('status', 'photo_transfer_pending');
  end if;
  if approved_photos is not null then
    -- Lock the reservations in the same order as preparation and cleanup.
    select count(*) into staged_count from (
      select s.name from private.household_join_staged_photos s
      where s.cleanup_claim is null and s.expires_at > now()
        and s.name in (select p->>'destination' from jsonb_array_elements(photos) p)
      order by s.name for update
    ) locked;
    if approved_photos <> photos or staged_count <> jsonb_array_length(photos) or exists (
      select 1 from jsonb_array_elements(photos) p
      where p->>'available' <> 'true' or not exists (
        select 1 from storage.objects o where o.bucket_id = 'recipe-photos'
        and o.name = p->>'destination'
        and o.metadata->'size' = p->'size'
        and o.metadata->'eTag' = p->'etag'
      )
    ) then
      return jsonb_build_object('status', 'photo_transfer_retry');
    end if;
    insert into private.household_join_published_photos (name, household_id)
      select p->>'destination', target_id from jsonb_array_elements(photos) p
      on conflict (name) do nothing;
    delete from private.household_join_staged_photos s
      where s.name in (select p->>'destination' from jsonb_array_elements(photos) p);
    select coalesce(jsonb_object_agg(p->>'leaf', split_part(p->>'destination', '/', 2)), '{}'::jsonb)
      into mapped_photos from jsonb_array_elements(photos) p;
  end if;

  if recipe_choice = 'bring_recipes' then
    for recipe in select r.* from public.recipes r
      where r.household_id = source_id and (r.created_by = uid or r.created_by is null)
      order by r.id for update
    loop
      copied_id := 'join-' || replace(gen_random_uuid()::text, '-', '');
      insert into public.recipes (id, household_id, title, servings, prep_minutes, source,
        ingredients, steps, image_path, answered_by, created_by, meal_types, weight, dish_kind, labels_source)
      values (copied_id, target_id, recipe.title, recipe.servings, recipe.prep_minutes,
        recipe.source, recipe.ingredients, recipe.steps,
        mapped_photos->>regexp_replace(recipe.image_path, '^recipe_photos/', ''),
        recipe.answered_by, uid,
        recipe.meal_types, recipe.weight, recipe.dish_kind, recipe.labels_source);
      insert into public.recipe_versions (id, household_id, recipe_id, recipe_json,
        instruction, change_kind, changed_by, created_at)
      select 'join-' || replace(gen_random_uuid()::text, '-', ''), target_id, copied_id,
        case when jsonb_typeof(v.recipe_json) = 'object' then
          v.recipe_json || jsonb_build_object('id', copied_id) ||
          case when v.recipe_json->>'imagePath' is not null then
            jsonb_build_object('imagePath', 'recipe_photos/' ||
              (mapped_photos->>regexp_replace(v.recipe_json->>'imagePath', '^recipe_photos/', '')))
          else '{}'::jsonb end
        else v.recipe_json end, v.instruction, v.change_kind, v.changed_by, v.created_at
        from public.recipe_versions v where v.recipe_id = recipe.id and v.household_id = source_id;
    end loop;
  end if;

  perform private.depart_household(source_id, uid);
  insert into public.household_members (household_id, user_id, role) values (target_id, uid, 'member');
  result := jsonb_build_object('status', 'joined', 'household_id', target_id);
  insert into private.household_join_operations (user_id, operation_id, request_hash, result)
    values (uid, operation_id, request_hash, result);
  return result;
end;
$$;

-- The worker runs without a user session. A failed invocation is eligible again
-- after its lease, including after the user's account has been deleted.
create function public.claim_household_photo_cleanup()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  claim_id uuid := gen_random_uuid();
  retired_id uuid;
  staged_paths text[];
  retired_paths text[];
begin
  select q.household_id into retired_id from private.household_join_photo_cleanup q
  where q.retry_at <= now()
    and not exists (select 1 from public.households h where h.id = q.household_id)
  order by q.retry_at, q.household_id limit 1 for update skip locked;

  if retired_id is not null then
    update private.household_join_photo_cleanup
      set retry_at = now() + interval '5 minutes' where household_id = retired_id;
    retired_paths := array(
      select o.name from storage.objects o
      where o.bucket_id = 'recipe-photos' and o.name like retired_id::text || '/%'
      order by o.name limit 100
    );
  end if;

  with due as (
    select s.name from private.household_join_staged_photos s
    where coalesce(s.cleanup_after, s.expires_at) <= now()
      and not exists (
        select 1 from private.household_join_published_photos p where p.name = s.name
      )
    order by s.name limit 100 for update skip locked
  ), claimed as (
    update private.household_join_staged_photos s
      set cleanup_claim = claim_id, cleanup_after = now() + interval '5 minutes'
    from due where s.name = due.name
    returning s.name
  )
  select coalesce(array_agg(name), array[]::text[]) into staged_paths from claimed;

  return jsonb_build_object('claim_id', claim_id, 'retired_id', retired_id,
    'retired_paths', retired_paths, 'staged_paths', staged_paths);
end;
$$;

create function public.complete_household_photo_cleanup(
  staged_claim_id uuid default null, retired_household_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.household_join_staged_photos s
  where s.cleanup_claim = staged_claim_id
    and not exists (select 1 from storage.objects o
      where o.bucket_id = 'recipe-photos' and o.name = s.name);

  delete from private.household_join_photo_cleanup q
  where q.household_id = retired_household_id
    and not exists (select 1 from public.households h where h.id = q.household_id)
    and not exists (select 1 from storage.objects o
      where o.bucket_id = 'recipe-photos' and o.name like q.household_id::text || '/%');
end;
$$;

revoke all on function public.claim_household_photo_cleanup(),
  public.complete_household_photo_cleanup(uuid, uuid) from public, anon, authenticated;
grant execute on function public.claim_household_photo_cleanup(),
  public.complete_household_photo_cleanup(uuid, uuid) to service_role;
