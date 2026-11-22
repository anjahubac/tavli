-- One private favorite per member and recipe. The ID is deterministic so two
-- offline devices converge on the same row. A favorite follows the recipe:
-- recipes copied to a new household carry it (household join), and leaving a
-- household removes favorites on that household's recipes.
create table public.user_favorites (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  recipe_id text not null references public.recipes (id) on delete cascade,
  recipe_household_id uuid not null references public.households (id) on delete cascade,
  is_favorite boolean not null,
  updated_at timestamptz not null default clock_timestamp(),
  unique (user_id, recipe_id),
  check (id = user_id::text || ':' || recipe_id)
);

create index user_favorites_sync_idx on public.user_favorites (user_id, updated_at, id);
create index user_favorites_recipe_idx on public.user_favorites (recipe_id);

create function private.keep_favorite_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(new.id, new.user_id, new.recipe_id, new.recipe_household_id)
      is distinct from
     row(old.id, old.user_id, old.recipe_id, old.recipe_household_id)
  then
    raise exception using errcode = '23514', message = 'Favorite identity cannot change';
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_favorite_identity() from public, anon, authenticated;
create trigger keep_identity before update on public.user_favorites
  for each row execute function private.keep_favorite_identity();

create trigger touch_updated_at before insert or update on public.user_favorites
  for each row execute function private.touch_updated_at();
create trigger record_deletion after delete on public.user_favorites
  for each row execute function private.record_deletion('favorite', 'id');
-- Leaving a household drops favorites on its recipes. SECURITY DEFINER because
-- the membership row is already gone, so RLS would hide those favorites.
create function private.drop_favorites_on_leave()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.user_favorites f
  where f.user_id = old.user_id and f.recipe_household_id = old.household_id;
  return old;
end;
$$;

revoke execute on function private.drop_favorites_on_leave() from public, anon, authenticated;
create trigger drop_favorites_on_leave after delete on public.household_members
  for each row execute function private.drop_favorites_on_leave();

-- The ID is the same after a rejoin, so a new favorite clears the old
-- tombstone first. A deleted recipe still blocks it (skip_if_deleted runs next).
create function private.revive_favorite()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.deletions d
    where d.entity = 'recipe' and d.record_id = new.recipe_id
  ) then
    delete from public.deletions d
    where d.entity = 'favorite' and d.record_id = new.id;
  end if;
  return new;
end;
$$;

revoke execute on function private.revive_favorite() from public, anon, authenticated;
-- Triggers fire in name order: revive_favorite before skip_if_deleted.
create trigger revive_favorite before insert on public.user_favorites
  for each row execute function private.revive_favorite();
create trigger skip_if_deleted before insert on public.user_favorites
  for each row execute function private.skip_if_deleted('favorite', 'id', 'recipe', 'recipe_id');

alter table public.user_favorites enable row level security;
grant select, insert, update on public.user_favorites to authenticated;
create policy "favorites: own visible select" on public.user_favorites
  for select to authenticated using (
    user_id = (select auth.uid()) and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.household_id = recipe_household_id
    )
  );
create policy "favorites: own visible insert" on public.user_favorites
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.household_id = recipe_household_id
    )
  );
create policy "favorites: own visible update" on public.user_favorites
  for update to authenticated using (
    user_id = (select auth.uid()) and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.household_id = recipe_household_id
    )
  ) with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.household_id = recipe_household_id
    )
  );
