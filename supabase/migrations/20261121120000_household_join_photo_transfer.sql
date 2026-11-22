-- D3-005: privatna priprema fotografija i objavljivanje u transakciji prelaska.
create table private.household_join_published_photos (
  name text primary key,
  household_id uuid not null references public.households (id) on delete cascade
);

create table private.household_join_photo_cleanup (
  household_id uuid primary key,
  user_id uuid references auth.users (id) on delete set null
);

alter table private.household_join_published_photos enable row level security;
alter table private.household_join_photo_cleanup enable row level security;
revoke all on private.household_join_published_photos, private.household_join_photo_cleanup
  from public, anon, authenticated;

create function private.join_photo_is_published(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(object_name, '/', 2) not like 'joinphoto-%'
    or exists (select 1 from private.household_join_published_photos p where p.name = object_name);
$$;

revoke all on function private.join_photo_is_published(text) from public, anon;
grant execute on function private.join_photo_is_published(text) to authenticated;

create policy "recipe photos: staged copies are private"
  on storage.objects as restrictive for all to authenticated
  using (bucket_id <> 'recipe-photos' or private.join_photo_is_published(name))
  with check (bucket_id <> 'recipe-photos' or private.join_photo_is_published(name));

create function private.household_join_photo_manifest(
  source_id uuid, target_id uuid, uid uuid, operation_id uuid
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with eligible as (
    select id, image_path from public.recipes
    where household_id = source_id and (created_by = uid or created_by is null)
  ), paths as (
    select image_path as path from eligible where image_path is not null
    union
    select v.recipe_json->>'imagePath' from public.recipe_versions v
      join eligible r on r.id = v.recipe_id
      where v.household_id = source_id and v.recipe_json->>'imagePath' is not null
  ), normalized as (
    select distinct regexp_replace(path, '^recipe_photos/', '') as leaf from paths
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'leaf', n.leaf,
    'source', source_id::text || '/' || n.leaf,
    'destination', target_id::text || '/joinphoto-' ||
      encode(extensions.digest(uid::text || ':' || operation_id::text || ':' ||
        source_id::text || ':' || n.leaf || ':' ||
        coalesce(o.version, o.id::text) || ':' || o.updated_at::text, 'sha256'), 'hex') || '.jpg',
    'available', o.id is not null and n.leaf ~ '^[A-Za-z0-9_-]{1,96}\.jpg$',
    'version', o.version,
    'size', o.metadata->'size',
    'etag', o.metadata->'eTag'
  ) order by n.leaf), '[]'::jsonb)
  from normalized n
  left join storage.objects o on o.bucket_id = 'recipe-photos'
    and o.name = source_id::text || '/' || n.leaf;
$$;

revoke all on function private.household_join_photo_manifest(uuid, uuid, uuid, uuid)
  from public, anon, authenticated;

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
  target_id uuid;
  photos jsonb := '[]'::jsonb;
begin
  select i.household_id into target_id from private.household_invites i
    where i.token = private.normalize_household_invite_code(prepare_household_join_photos.token);
  if target_id is null or target_id = source_id then
    return jsonb_build_object('status', 'unavailable');
  end if;
  if not exists (
    select 1 from public.household_members m
      where m.user_id = caller_id and m.household_id = source_id
  ) then
    return jsonb_build_object('status', 'stale_source');
  end if;
  if source_deletion_ack is not true and (
    select count(*) = 1 from public.household_members m where m.household_id = source_id
  ) then
    return jsonb_build_object('status', 'source_deletion_confirmation_required');
  end if;
  if recipe_choice = 'bring_recipes' then
    photos := private.household_join_photo_manifest(source_id, target_id, caller_id, operation_id);
    if exists (select 1 from jsonb_array_elements(photos) p where p->>'available' <> 'true') then
      return jsonb_build_object('status', 'photo_unavailable');
    end if;
  end if;
  return jsonb_build_object('status', 'ready', 'photos', photos);
end;
$$;

revoke all on function public.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_household_join_photos(uuid, text, uuid, text, boolean, uuid)
  to service_role;

create function private.apply_household_join(
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
  next_owner uuid;
  photos jsonb := '[]'::jsonb;
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
    if approved_photos <> photos or exists (
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
        instruction, change_kind, changed_by)
      select 'join-' || replace(gen_random_uuid()::text, '-', ''), target_id, copied_id,
        case when jsonb_typeof(v.recipe_json) = 'object' then
          v.recipe_json || jsonb_build_object('id', copied_id) ||
          case when v.recipe_json->>'imagePath' is not null then
            jsonb_build_object('imagePath', 'recipe_photos/' ||
              (mapped_photos->>regexp_replace(v.recipe_json->>'imagePath', '^recipe_photos/', '')))
          else '{}'::jsonb end
        else v.recipe_json end, v.instruction, v.change_kind, v.changed_by
        from public.recipe_versions v where v.recipe_id = recipe.id and v.household_id = source_id;
    end loop;
  end if;

  if source_count > 1 and exists (
    select 1 from public.household_members m where m.household_id = source_id and m.user_id = uid and m.role = 'owner'
  ) then
    select m.user_id into next_owner from public.household_members m
     where m.household_id = source_id and m.user_id <> uid
     order by m.joined_at, m.user_id limit 1;
    update public.household_members set role = 'owner'
     where household_id = source_id and user_id = next_owner;
  end if;
  delete from public.household_members where household_id = source_id and user_id = uid;
  insert into public.household_members (household_id, user_id, role) values (target_id, uid, 'member');
  if source_count = 1 then
    if approved_photos is not null then
      insert into private.household_join_photo_cleanup (household_id, user_id) values (source_id, uid);
    end if;
    delete from public.households where id = source_id;
  end if;
  result := jsonb_build_object('status', 'joined', 'household_id', target_id);
  insert into private.household_join_operations (user_id, operation_id, request_hash, result)
    values (uid, operation_id, request_hash, result);
  return result;
end;
$$;

revoke all on function private.apply_household_join(text, uuid, text, boolean, uuid, uuid, jsonb)
  from public, anon, authenticated;

create or replace function private.confirm_household_join(
  token text, expected_source_household_id uuid, recipe_choice text,
  source_deletion_ack boolean, operation_id uuid
)
returns jsonb
language sql
set search_path = ''
as $$
  select private.apply_household_join(
    private.normalize_household_invite_code(token), expected_source_household_id,
    recipe_choice, source_deletion_ack, operation_id, auth.uid(), null
  );
$$;

create function public.finish_household_join_photos(
  caller_id uuid, token text, source_id uuid, recipe_choice text,
  source_deletion_ack boolean, operation_id uuid, photos jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.apply_household_join(
    private.normalize_household_invite_code(token), source_id, recipe_choice,
    source_deletion_ack, operation_id, caller_id, photos
  );
$$;

create function public.household_join_photo_cleanup(caller_id uuid, completed_id uuid)
returns setof uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if completed_id is not null then
    delete from private.household_join_photo_cleanup q
      where q.user_id = caller_id and q.household_id = completed_id
        and not exists (
          select 1 from storage.objects o where o.bucket_id = 'recipe-photos'
            and o.name like completed_id::text || '/%'
        );
  end if;
  return query select q.household_id from private.household_join_photo_cleanup q
    where q.user_id = caller_id limit 10;
end;
$$;

revoke all on function public.finish_household_join_photos(uuid, text, uuid, text, boolean, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.household_join_photo_cleanup(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.finish_household_join_photos(uuid, text, uuid, text, boolean, uuid, jsonb)
  to service_role;
grant execute on function public.household_join_photo_cleanup(uuid, uuid) to service_role;
