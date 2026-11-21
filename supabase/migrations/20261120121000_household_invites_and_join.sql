-- D3-005: trajni linkovi i direktno pridruživanje domaćinstvu.

create extension if not exists pgcrypto with schema extensions;

alter table public.household_members
  drop constraint household_members_role_check,
  add constraint household_members_role_check check (role in ('owner', 'member'));

create unique index household_members_one_per_user_idx
  on public.household_members (user_id);

alter table public.recipes
  add column created_by uuid references auth.users (id) on delete set null;

create table private.household_invites (
  household_id uuid primary key references public.households (id) on delete cascade,
  token text not null unique default encode(extensions.gen_random_bytes(32), 'hex'),
  created_at timestamptz not null default now()
);

create table private.household_join_operations (
  user_id uuid not null references auth.users (id) on delete cascade,
  operation_id uuid not null,
  request_hash text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, operation_id)
);

revoke all on private.household_invites, private.household_join_operations
  from public, anon, authenticated;

grant usage on schema private to anon;

create or replace function public.household_invite_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  invite text;
begin
  if uid is null then raise insufficient_privilege; end if;
  select m.household_id into hid from public.household_members m
   where m.user_id = uid and m.role = 'owner';
  if hid is null then raise insufficient_privilege; end if;
  insert into private.household_invites (household_id) values (hid)
    on conflict (household_id) do nothing;
  select i.token into invite from private.household_invites i where i.household_id = hid;
  return invite;
end;
$$;

create or replace function public.preview_household_join(token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  target_id uuid;
  source_id uuid;
  target_name text;
  last_member boolean;
begin
  if uid is null then raise insufficient_privilege; end if;
  select i.household_id, h.name into target_id, target_name
    from private.household_invites i
    join public.households h on h.id = i.household_id
   where i.token = preview_household_join.token;
  if target_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  select m.household_id into source_id from public.household_members m where m.user_id = uid;
  if source_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  select count(*) = 1 into last_member from public.household_members m where m.household_id = source_id;
  return jsonb_build_object('status', 'available', 'household_name', target_name,
    'source_household_id', source_id,
    'requires_source_deletion_ack', last_member and source_id <> target_id);
end;
$$;

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
  if recipe_choice not in ('bring_recipes', 'leave_recipes') or operation_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;
  request_hash := encode(extensions.digest(
    token || ':' || expected_source_household_id::text || ':' || recipe_choice || ':' || source_deletion_ack::text,
    'sha256'), 'hex');
  select * into prior from private.household_join_operations o
   where o.user_id = uid and o.operation_id = confirm_household_join.operation_id;
  if found then
    if prior.request_hash <> request_hash then return jsonb_build_object('status', 'operation_conflict'); end if;
    return prior.result;
  end if;
  select i.household_id into target_id from private.household_invites i
   where i.token = confirm_household_join.token for update;
  if target_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  perform 1 from public.households h where h.id = target_id for update;
  select m.household_id into source_id from public.household_members m
   where m.user_id = uid for update;
  if source_id is null then return jsonb_build_object('status', 'unavailable'); end if;
  if source_id = target_id then return jsonb_build_object('status', 'already_member'); end if;
  if source_id <> expected_source_household_id then return jsonb_build_object('status', 'stale_source'); end if;
  perform 1 from public.households h where h.id = source_id for update;
  select count(*) into source_count from public.household_members m where m.household_id = source_id;
  if source_count = 1 and not source_deletion_ack then
    return jsonb_build_object('status', 'source_deletion_confirmation_required');
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
        v.recipe_json, v.instruction, v.change_kind, v.changed_by
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

revoke all on function public.household_invite_token() from public, anon;
revoke all on function public.preview_household_join(text) from public, anon;
revoke all on function public.confirm_household_join(text, uuid, text, boolean, uuid) from public, anon;
grant execute on function public.household_invite_token() to authenticated;
grant execute on function public.preview_household_join(text) to authenticated;
grant execute on function public.confirm_household_join(text, uuid, text, boolean, uuid) to authenticated;

create or replace function private.set_recipe_creator()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

revoke execute on function private.set_recipe_creator() from public, anon, authenticated;

create trigger set_recipe_creator
  before insert or update of created_by on public.recipes
  for each row execute function private.set_recipe_creator();
