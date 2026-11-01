-- 006a: Row Level Security na svakoj tabeli i izričita prava (FR-020).
-- anon nema nikakva prava; authenticated samo ono što aplikaciji treba.

revoke all on all tables in schema public from anon, authenticated;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.deletions enable row level security;
alter table public.ratings enable row level security;
alter table public.taste_profiles enable row level security;

alter table public.recipes enable row level security;
alter table public.recipe_versions enable row level security;
alter table public.shopping_lists enable row level security;
alter table public.shopping_items enable row level security;
alter table public.pantry_items enable row level security;
alter table public.meal_plans enable row level security;
alter table public.meal_plan_entries enable row level security;

-- Prava za authenticated (anon: ništa).
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant select on public.households, public.household_members, public.deletions to authenticated;
grant select, insert, update, delete on
  public.recipes, public.recipe_versions, public.shopping_lists, public.shopping_items,
  public.pantry_items, public.meal_plans, public.meal_plan_entries,
  public.ratings, public.taste_profiles
  to authenticated;

-- Nalog
create policy "profiles: own select" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "profiles: own update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "households: members select" on public.households
  for select to authenticated using (private.is_member(id));

create policy "household_members: members select" on public.household_members
  for select to authenticated using (private.is_member(household_id));

create policy "deletions: own or member select" on public.deletions
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_member(household_id));

-- Podaci domaćinstva: samo članovi; red ne može da se premesti u tuđe domaćinstvo.
create policy "recipes: members select" on public.recipes
  for select to authenticated using (private.is_member(household_id));
create policy "recipes: members insert" on public.recipes
  for insert to authenticated with check (private.is_member(household_id));
create policy "recipes: members update" on public.recipes
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "recipes: members delete" on public.recipes
  for delete to authenticated using (private.is_member(household_id));
create policy "recipe_versions: members select" on public.recipe_versions
  for select to authenticated using (private.is_member(household_id));
create policy "recipe_versions: members insert" on public.recipe_versions
  for insert to authenticated with check (private.is_member(household_id));
create policy "recipe_versions: members update" on public.recipe_versions
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "recipe_versions: members delete" on public.recipe_versions
  for delete to authenticated using (private.is_member(household_id));
create policy "shopping_lists: members select" on public.shopping_lists
  for select to authenticated using (private.is_member(household_id));
create policy "shopping_lists: members insert" on public.shopping_lists
  for insert to authenticated with check (private.is_member(household_id));
create policy "shopping_lists: members update" on public.shopping_lists
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "shopping_lists: members delete" on public.shopping_lists
  for delete to authenticated using (private.is_member(household_id));
create policy "shopping_items: members select" on public.shopping_items
  for select to authenticated using (private.is_member(household_id));
create policy "shopping_items: members insert" on public.shopping_items
  for insert to authenticated with check (private.is_member(household_id));
create policy "shopping_items: members update" on public.shopping_items
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "shopping_items: members delete" on public.shopping_items
  for delete to authenticated using (private.is_member(household_id));
create policy "pantry_items: members select" on public.pantry_items
  for select to authenticated using (private.is_member(household_id));
create policy "pantry_items: members insert" on public.pantry_items
  for insert to authenticated with check (private.is_member(household_id));
create policy "pantry_items: members update" on public.pantry_items
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "pantry_items: members delete" on public.pantry_items
  for delete to authenticated using (private.is_member(household_id));
create policy "meal_plans: members select" on public.meal_plans
  for select to authenticated using (private.is_member(household_id));
create policy "meal_plans: members insert" on public.meal_plans
  for insert to authenticated with check (private.is_member(household_id));
create policy "meal_plans: members update" on public.meal_plans
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "meal_plans: members delete" on public.meal_plans
  for delete to authenticated using (private.is_member(household_id));
create policy "meal_plan_entries: members select" on public.meal_plan_entries
  for select to authenticated using (private.is_member(household_id));
create policy "meal_plan_entries: members insert" on public.meal_plan_entries
  for insert to authenticated with check (private.is_member(household_id));
create policy "meal_plan_entries: members update" on public.meal_plan_entries
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "meal_plan_entries: members delete" on public.meal_plan_entries
  for delete to authenticated using (private.is_member(household_id));

-- Lični podaci: samo vlasnik; ocena samo za recept iz svog domaćinstva.
create policy "ratings: own select" on public.ratings
  for select to authenticated using (user_id = (select auth.uid()));
create policy "ratings: own insert" on public.ratings
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and private.is_member((select r.household_id from public.recipes r where r.id = recipe_id))
  );
create policy "ratings: own update" on public.ratings
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and private.is_member((select r.household_id from public.recipes r where r.id = recipe_id))
  );
create policy "ratings: own delete" on public.ratings
  for delete to authenticated using (user_id = (select auth.uid()));

create policy "taste_profiles: own select" on public.taste_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "taste_profiles: own insert" on public.taste_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "taste_profiles: own update" on public.taste_profiles
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "taste_profiles: own delete" on public.taste_profiles
  for delete to authenticated using (user_id = (select auth.uid()));
