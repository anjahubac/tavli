-- Each membership has its own identity so offline writes cannot outlive access,
-- including when a user later rejoins the same household.
alter table public.household_members
  add column favorite_membership_id uuid not null default gen_random_uuid(),
  add constraint household_members_favorite_identity
    unique (household_id, user_id, favorite_membership_id);

create table public.user_favorites (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  recipe_id text not null references public.recipes (id) on delete cascade,
  recipe_household_id uuid not null,
  membership_id uuid not null,
  is_favorite boolean not null,
  updated_at timestamptz not null default clock_timestamp(),
  unique (user_id, recipe_id),
  check (id = membership_id::text || ':' || recipe_id),
  foreign key (recipe_household_id, user_id, membership_id)
    references public.household_members (household_id, user_id, favorite_membership_id)
    on delete cascade
);

create index user_favorites_sync_idx on public.user_favorites (user_id, updated_at, id);
create index user_favorites_recipe_idx on public.user_favorites (recipe_id);

create function private.keep_favorite_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if row(new.id, new.user_id, new.recipe_id, new.recipe_household_id, new.membership_id)
      is distinct from
     row(old.id, old.user_id, old.recipe_id, old.recipe_household_id, old.membership_id)
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
