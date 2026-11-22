create table public.user_planning_sharing (
  user_id uuid primary key references auth.users (id) on delete cascade,
  preferences boolean not null default false,
  revision bigint not null check (revision > 0)
);

alter table public.user_planning_sharing enable row level security;
grant select on public.user_planning_sharing to authenticated;
create policy "planning sharing: own select" on public.user_planning_sharing
  for select to authenticated using (user_id = (select auth.uid()));

-- Consent changes are acknowledged online only. Revision zero is an absent row.
create function public.set_planning_preferences_sharing(expected_revision bigint, enabled boolean)
returns table (preferences boolean, revision bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;
  if enabled is null or expected_revision is null or expected_revision < 0 then
    raise exception using errcode = '22023', message = 'Invalid consent change';
  end if;

  if expected_revision = 0 then
    return query
      insert into public.user_planning_sharing as sharing (user_id, preferences, revision)
        values (actor, enabled, 1)
      on conflict (user_id) do nothing
      returning sharing.preferences, sharing.revision;
  else
    return query
      update public.user_planning_sharing as sharing
      set preferences = enabled, revision = sharing.revision + 1
      where sharing.user_id = actor and sharing.revision = expected_revision
      returning sharing.preferences, sharing.revision;
  end if;

  if not found then
    raise exception using errcode = 'P0001', message = 'Consent revision changed';
  end if;
end;
$$;

revoke execute on function public.set_planning_preferences_sharing(bigint, boolean)
  from public, anon, authenticated;
grant execute on function public.set_planning_preferences_sharing(bigint, boolean)
  to authenticated;

-- Only a trusted server consumer can supply actor_id. No member can invoke this
-- directly. Verify the entire set before reading any private settings.
create function private.validated_planning_participants(
  actor_id uuid, target_household uuid, participant_ids uuid[]
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select from public.household_members m
    where m.household_id = target_household and m.user_id = actor_id
  ) or coalesce(cardinality(participant_ids), 0) = 0
    or coalesce(array_ndims(participant_ids), 0) <> 1
    or cardinality(participant_ids) <> (
      select count(distinct selected.id)
      from unnest(participant_ids) selected(id)
      join public.household_members m
        on m.user_id = selected.id and m.household_id = target_household
    )
  then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;

  return participant_ids;
end;
$$;

create function public.planning_allergen_codes(
  actor_id uuid, target_household uuid, participant_ids uuid[]
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  authorized_ids uuid[] := private.validated_planning_participants(
    actor_id, target_household, participant_ids
  );
begin
  return array(
    select distinct group_code
    from public.user_allergen_selections s
    cross join lateral unnest(s.group_codes) as groups(group_code)
    where s.user_id = any(authorized_ids)
    order by group_code
  );
end;
$$;

revoke execute on function private.validated_planning_participants(uuid, uuid, uuid[])
  from public, anon, authenticated;
revoke execute on function public.planning_allergen_codes(uuid, uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.planning_allergen_codes(uuid, uuid, uuid[])
  to service_role;

-- The trusted server supplies catalog IDs visible in the target household.
-- The default empty allowlist safely omits foods until the catalog is wired.
create function public.planning_advisory_inputs(
  actor_id uuid, target_household uuid, participant_ids uuid[],
  for_provider boolean, visible_food_ids text[] default '{}'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  authorized_ids uuid[] := private.validated_planning_participants(
    actor_id, target_household, participant_ids
  );
  result jsonb;
begin
  if for_provider is null then
    raise exception using errcode = '22023', message = 'Missing planning destination';
  end if;

  with allowed as (
    select p.id
    from unnest(authorized_ids) as p(id)
    left join public.user_planning_sharing sharing on sharing.user_id = p.id
    where sharing.preferences
       or (not for_provider and cardinality(authorized_ids) = 1 and p.id = actor_id)
  ),
  preference_values as (
    select flags.category, chosen.value, flags.disliked
    from allowed a
    join public.taste_profiles t on t.user_id = a.id
    cross join (values
      ('dish', 'likedDishKinds', false), ('dish', 'dislikedDishKinds', true),
      ('food', 'likedFoodIds', false), ('food', 'dislikedFoodIds', true),
      ('cuisine', 'likedCuisineCodes', false), ('cuisine', 'dislikedCuisineCodes', true)
    ) flags(category, key, disliked)
    cross join lateral jsonb_array_elements_text(
      case when jsonb_typeof(t.profile -> flags.key) = 'array'
        then t.profile -> flags.key else '[]'::jsonb end
    ) as chosen(value)
    where (
      flags.category = 'dish' and chosen.value in (
        'soup', 'cooked', 'baked_fried', 'pasta', 'salad', 'pie_pizza_sandwich',
        'eggs_breakfast', 'cold', 'sweet'
      )
    ) or (flags.category = 'food' and chosen.value = any(visible_food_ids))
      or (flags.category = 'cuisine' and chosen.value in (
        'serbian', 'italian', 'japanese', 'french', 'mexican'
      ))
  ),
  effective_preferences as (
    select category, value, bool_or(disliked) as disliked
    from preference_values group by category, value
  ),
  favorites as (
    select f.recipe_id, count(*) as member_count
    from allowed a
    join public.user_favorites f on f.user_id = a.id
    join public.recipes r on r.id = f.recipe_id and r.household_id = target_household
    where f.is_favorite and f.recipe_household_id = target_household
    group by f.recipe_id
  )
  select jsonb_build_object(
    'likedDishKinds', to_jsonb(array(
      select value from effective_preferences where category = 'dish' and not disliked order by value
    )),
    'dislikedDishKinds', to_jsonb(array(
      select value from effective_preferences where category = 'dish' and disliked order by value
    )),
    'likedFoodIds', to_jsonb(array(
      select value from effective_preferences where category = 'food' and not disliked order by value
    )),
    'dislikedFoodIds', to_jsonb(array(
      select value from effective_preferences where category = 'food' and disliked order by value
    )),
    'likedCuisineCodes', to_jsonb(array(
      select value from effective_preferences where category = 'cuisine' and not disliked order by value
    )),
    'dislikedCuisineCodes', to_jsonb(array(
      select value from effective_preferences where category = 'cuisine' and disliked order by value
    )),
    'favoriteRecipeCounts', coalesce(
      (select jsonb_object_agg(recipe_id, member_count) from favorites), '{}'::jsonb
    )
  ) into result;
  return result;
end;
$$;

revoke execute on function public.planning_advisory_inputs(uuid, uuid, uuid[], boolean, text[])
  from public, anon, authenticated;
grant execute on function public.planning_advisory_inputs(uuid, uuid, uuid[], boolean, text[])
  to service_role;
