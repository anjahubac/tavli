-- 006a: podaci domaćinstva. Id pravi uređaj (tekst), pa ponovljeno slanje
-- ne pravi duplikate. Deca imaju složen strani ključ (roditelj, domaćinstvo),
-- pa red ne može da pokazuje na roditelja iz tuđeg domaćinstva.

create table public.recipes (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  title text not null,
  servings int not null check (servings > 0),
  prep_minutes int,
  source text not null,
  ingredients jsonb not null,
  steps jsonb not null,
  image_path text,
  answered_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id)
);

create table public.recipe_versions (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  recipe_id text not null,
  recipe_json jsonb not null,
  instruction text,
  change_kind text not null,
  changed_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  foreign key (recipe_id, household_id)
    references public.recipes (id, household_id) on delete cascade
);

create table public.meal_plans (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  start_date timestamptz not null,
  end_date timestamptz not null,
  meal_types jsonb not null,
  use_pantry boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id)
);

create table public.shopping_lists (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  meal_plan_id text,
  week int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id),
  foreign key (meal_plan_id, household_id)
    references public.meal_plans (id, household_id) on delete set null (meal_plan_id)
);

create table public.shopping_items (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  list_id text not null,
  name text not null,
  quantity double precision,
  unit text,
  category text not null,
  is_bought boolean not null default false,
  is_manual boolean not null default false,
  from_recipe_ids jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  foreign key (list_id, household_id)
    references public.shopping_lists (id, household_id) on delete cascade
);

create table public.pantry_items (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  quantity double precision,
  unit text,
  category text not null,
  added_at timestamptz not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

create table public.meal_plan_entries (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  plan_id text not null,
  date timestamptz not null,
  meal_type text not null,
  recipe_id text,
  is_locked boolean not null default false,
  is_cooked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  foreign key (plan_id, household_id)
    references public.meal_plans (id, household_id) on delete cascade,
  foreign key (recipe_id, household_id)
    references public.recipes (id, household_id) on delete set null (recipe_id)
);

-- Preuzimanje po (updated_at, id) unutar domaćinstva.
create index recipes_sync_idx on public.recipes (household_id, updated_at, id);
create index recipe_versions_sync_idx on public.recipe_versions (household_id, updated_at, id);
create index meal_plans_sync_idx on public.meal_plans (household_id, updated_at, id);
create index shopping_lists_sync_idx on public.shopping_lists (household_id, updated_at, id);
create index shopping_items_sync_idx on public.shopping_items (household_id, updated_at, id);
create index pantry_items_sync_idx on public.pantry_items (household_id, updated_at, id);
create index meal_plan_entries_sync_idx on public.meal_plan_entries (household_id, updated_at, id);

-- Za kaskade po stranim ključevima.
create index recipe_versions_recipe_idx on public.recipe_versions (recipe_id, household_id);
create index shopping_lists_plan_idx on public.shopping_lists (meal_plan_id, household_id);
create index shopping_items_list_idx on public.shopping_items (list_id, household_id);
create index meal_plan_entries_plan_idx on public.meal_plan_entries (plan_id, household_id);
create index meal_plan_entries_recipe_idx on public.meal_plan_entries (recipe_id, household_id);

create trigger touch_updated_at before insert or update on public.recipes
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.recipe_versions
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.meal_plans
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.shopping_lists
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.shopping_items
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.pantry_items
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.meal_plan_entries
  for each row execute function private.touch_updated_at('updated_by');
