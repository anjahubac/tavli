-- One current private rating per member and saved recipe.
-- Keep the most recently cooked row if a pre-existing account has duplicates.
with ranked as (
  select id,
         row_number() over (
           partition by user_id, recipe_id
           order by cooked_at desc, id desc
         ) as position
  from public.ratings
)
delete from public.ratings r
using ranked d
where r.id = d.id and d.position > 1;

create unique index ratings_user_recipe_unique
  on public.ratings (user_id, recipe_id);

-- An offline first write on a second device must keep the existing server ID.
create function private.keep_rating_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.id := old.id;
  return new;
end;
$$;
revoke execute on function private.keep_rating_identity() from public, anon, authenticated;
create trigger keep_rating_identity before update on public.ratings
  for each row execute function private.keep_rating_identity();

-- The caller may see only a household aggregate. SECURITY DEFINER is needed
-- because ratings rows remain owner-only under RLS; membership is checked here
-- for each recipe and no member-level fields leave the function.
create or replace function public.get_household_recipe_rating_summaries()
returns table (
  household_id uuid,
  recipe_id text,
  average_stars numeric,
  rating_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select recipe.household_id,
         rating.recipe_id,
         round(avg(rating.stars)::numeric, 1),
         count(*)
  from public.ratings rating
  join public.recipes recipe on recipe.id = rating.recipe_id
  join public.household_members member
    on member.household_id = recipe.household_id and member.user_id = rating.user_id
  where private.is_member(recipe.household_id)
  group by recipe.household_id, rating.recipe_id;
$$;

revoke all on function public.get_household_recipe_rating_summaries()
  from public, anon, authenticated;
grant execute on function public.get_household_recipe_rating_summaries()
  to authenticated;
