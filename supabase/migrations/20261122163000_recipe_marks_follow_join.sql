-- A brought recipe keeps the mover's favorite and rating; left-behind recipes
-- lose them. The join copies both before departing, because leaving the source
-- household deletes the mover's marks on its recipes.

-- Copies one member's favorite and rating from a source recipe to its copy.
create function private.copy_recipe_marks(
  source_recipe_id text, copied_recipe_id text, uid uuid, target_household_id uuid
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.user_favorites (id, user_id, recipe_id, recipe_household_id, is_favorite)
  select uid::text || ':' || copied_recipe_id, uid, copied_recipe_id, target_household_id, f.is_favorite
    from public.user_favorites f
   where f.user_id = uid and f.recipe_id = source_recipe_id;

  insert into public.ratings (id, user_id, recipe_id, stars, is_comfort_food, comment, cooked_at, created_at)
  select 'join-' || replace(gen_random_uuid()::text, '-', ''), uid, copied_recipe_id,
         r.stars, r.is_comfort_food, r.comment, r.cooked_at, r.created_at
    from public.ratings r
   where r.user_id = uid and r.recipe_id = source_recipe_id;
end;
$$;

revoke all on function private.copy_recipe_marks(text, text, uuid, uuid)
  from public, anon, authenticated, service_role;

-- Leaving a household drops the member's favorites and ratings on its recipes.
create or replace function private.drop_recipe_marks_on_leave()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_favorites f
  where f.user_id = old.user_id and f.recipe_household_id = old.household_id;
  delete from public.ratings r
  using public.recipes recipe
  where r.user_id = old.user_id and recipe.id = r.recipe_id
    and recipe.household_id = old.household_id;
  return old;
end;
$$;

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
      perform private.copy_recipe_marks(recipe.id, copied_id, uid, target_id);
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

