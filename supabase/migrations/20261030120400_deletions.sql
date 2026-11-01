-- 006a: brisanja su prava (DELETE), a okidač ostavlja trag (tombstone) da bi
-- ga drugi uređaji preuzeli. Ubacivanje obrisanog id-a (ili deteta obrisanog
-- roditelja) se tiho preskače: brisanje pobeđuje izmenu (FR-017).

create table public.deletions (
  entity text not null,
  record_id text not null,
  household_id uuid,
  user_id uuid,
  deleted_at timestamptz not null default clock_timestamp(),
  -- Jedinstven ključ za preuzimanje po (deleted_at, id).
  id text generated always as (entity || '/' || record_id) stored,
  primary key (entity, record_id),
  check ((household_id is null) <> (user_id is null))
);

create index deletions_household_idx on public.deletions (household_id, deleted_at, id);
create index deletions_user_idx on public.deletions (user_id, deleted_at, id);

-- Argumenti: entitet, kolona sa id-jem.
create or replace function private.record_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r jsonb := to_jsonb(old);
begin
  insert into public.deletions (entity, record_id, household_id, user_id)
  values (
    tg_argv[0],
    r ->> tg_argv[1],
    (r ->> 'household_id')::uuid,
    case when r ? 'household_id' then null else (r ->> 'user_id')::uuid end
  )
  on conflict (entity, record_id) do nothing;
  return old;
end;
$$;

-- Argumenti: entitet, kolona sa id-jem, pa parovi (entitet roditelja, kolona).
create or replace function private.skip_if_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r jsonb := to_jsonb(new);
  i int := 2;
begin
  if exists (
    select 1 from public.deletions d
    where d.entity = tg_argv[0] and d.record_id = r ->> tg_argv[1]
  ) then
    return null;
  end if;
  while i + 1 < tg_nargs loop
    if r ->> tg_argv[i + 1] is not null and exists (
      select 1 from public.deletions d
      where d.entity = tg_argv[i] and d.record_id = r ->> tg_argv[i + 1]
    ) then
      return null;
    end if;
    i := i + 2;
  end loop;
  return new;
end;
$$;

revoke execute on function private.record_deletion() from public, anon, authenticated;
revoke execute on function private.skip_if_deleted() from public, anon, authenticated;

create trigger record_deletion after delete on public.recipes
  for each row execute function private.record_deletion('recipe', 'id');
create trigger record_deletion after delete on public.recipe_versions
  for each row execute function private.record_deletion('recipe_version', 'id');
create trigger record_deletion after delete on public.shopping_lists
  for each row execute function private.record_deletion('shopping_list', 'id');
create trigger record_deletion after delete on public.shopping_items
  for each row execute function private.record_deletion('shopping_item', 'id');
create trigger record_deletion after delete on public.pantry_items
  for each row execute function private.record_deletion('pantry_item', 'id');
create trigger record_deletion after delete on public.meal_plans
  for each row execute function private.record_deletion('meal_plan', 'id');
create trigger record_deletion after delete on public.meal_plan_entries
  for each row execute function private.record_deletion('meal_plan_entry', 'id');
create trigger record_deletion after delete on public.ratings
  for each row execute function private.record_deletion('rating', 'id');
create trigger record_deletion after delete on public.taste_profiles
  for each row execute function private.record_deletion('taste_profile', 'user_id');

create trigger skip_if_deleted before insert on public.recipes
  for each row execute function private.skip_if_deleted('recipe', 'id');
create trigger skip_if_deleted before insert on public.recipe_versions
  for each row execute function private.skip_if_deleted('recipe_version', 'id', 'recipe', 'recipe_id');
create trigger skip_if_deleted before insert on public.shopping_lists
  for each row execute function private.skip_if_deleted('shopping_list', 'id');
create trigger skip_if_deleted before insert on public.shopping_items
  for each row execute function private.skip_if_deleted('shopping_item', 'id', 'shopping_list', 'list_id');
create trigger skip_if_deleted before insert on public.pantry_items
  for each row execute function private.skip_if_deleted('pantry_item', 'id');
create trigger skip_if_deleted before insert on public.meal_plans
  for each row execute function private.skip_if_deleted('meal_plan', 'id');
create trigger skip_if_deleted before insert on public.meal_plan_entries
  for each row execute function private.skip_if_deleted('meal_plan_entry', 'id', 'meal_plan', 'plan_id');
create trigger skip_if_deleted before insert on public.ratings
  for each row execute function private.skip_if_deleted('rating', 'id', 'recipe', 'recipe_id');
