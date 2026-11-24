-- D3-005: potvrda brisanja, redosled zaključavanja i zaštita slika.
revoke usage on schema private from anon;

alter table private.household_invites enable row level security;
alter table private.household_join_operations enable row level security;

create or replace function public.confirm_household_join(
  token text,
  expected_source_household_id uuid,
  recipe_choice text,
  source_deletion_ack boolean,
  operation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  target_id uuid;
  source_id uuid;
  source_count bigint;
  request_hash text;
  prior private.household_join_operations%rowtype;
  result jsonb;
  recipe public.recipes%rowtype;
  copied_id text;
  next_owner uuid;
begin
  if uid is null then raise insufficient_privilege; end if;
  if recipe_choice is null or recipe_choice not in ('bring_recipes', 'leave_recipes')
     or operation_id is null or expected_source_household_id is null
     or source_deletion_ack is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;
  if token is null or length(token) <> 64 or token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'unavailable');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  request_hash := encode(extensions.digest(
    token || ':' || expected_source_household_id::text || ':' || recipe_choice || ':' || source_deletion_ack::text,
    'sha256'), 'hex');
  select * into prior from private.household_join_operations o
   where o.user_id = uid and o.operation_id = confirm_household_join.operation_id;
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
   where i.token = confirm_household_join.token;
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

  -- Storage API kopira i briše fizičke objekte. Dok taj tok nije povezan,
  -- zadržavamo članstvo i sve podatke kad bi prelazak zahtevao rad sa slikama.
  if (source_count = 1 and exists (
    select 1 from storage.objects o where o.bucket_id = 'recipe-photos'
      and o.name like source_id::text || '/%'
  )) or (recipe_choice = 'bring_recipes' and exists (
    select 1 from public.recipes r where r.household_id = source_id
      and (r.created_by = uid or r.created_by is null)
      and (r.image_path is not null or exists (
        select 1 from public.recipe_versions v where v.recipe_id = r.id
          and v.household_id = source_id and v.recipe_json->>'imagePath' is not null
      ))
  )) then
    return jsonb_build_object('status', 'photo_transfer_pending');
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
        recipe.source, recipe.ingredients, recipe.steps, null, recipe.answered_by, uid,
        recipe.meal_types, recipe.weight, recipe.dish_kind, recipe.labels_source);
      insert into public.recipe_versions (id, household_id, recipe_id, recipe_json,
        instruction, change_kind, changed_by)
      select 'join-' || replace(gen_random_uuid()::text, '-', ''), target_id, copied_id,
        case when jsonb_typeof(v.recipe_json) = 'object' and v.recipe_json ? 'id'
          then jsonb_set(v.recipe_json, '{id}', to_jsonb(copied_id))
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
    delete from public.households where id = source_id;
  end if;
  result := jsonb_build_object('status', 'joined', 'household_id', target_id);
  insert into private.household_join_operations (user_id, operation_id, request_hash, result)
    values (uid, operation_id, request_hash, result);
  return result;
end;
$$;
