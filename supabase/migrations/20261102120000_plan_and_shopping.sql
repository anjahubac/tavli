-- 010: plan i nabavka. Porcije i odobren recept u planu, nedeljni delovi
-- listi, zamrznuto poreklo kupovine, prijem kupovine u ostavu i tri nove
-- tabele: izvori potražnje, doprinosi i raspodela zalihe. Samo dodaje;
-- postojeći redovi i id-jevi ostaju, stare liste se ne dele na nedelje.

-- Plan: porcije za nove obroke; obrok: porcije i odobren recept.
alter table public.meal_plans
  add column default_servings int not null default 2
    check (default_servings between 1 and 20);

alter table public.meal_plan_entries
  add column servings int check (servings between 1 and 20),
  add column recipe_snapshot jsonb
    check (recipe_snapshot is null or jsonb_typeof(recipe_snapshot) = 'object'),
  add unique (id, household_id);

-- Postojeći obroci dobijaju recept kakav je sada u biblioteci.
update public.meal_plan_entries e
   set recipe_snapshot = jsonb_build_object(
         'title', r.title, 'servings', r.servings, 'prepMinutes', r.prep_minutes,
         'ingredients', r.ingredients, 'steps', r.steps, 'imagePath', r.image_path)
  from public.recipes r
 where r.id = e.recipe_id and r.household_id = e.household_id
   and e.recipe_snapshot is null;

-- Lista: nedeljni deo plana kao kalendarski datumi (ponoć UTC), do 6 nedelja.
alter table public.shopping_lists
  add column period_start timestamptz,
  add column period_end timestamptz,
  add check (week is null or week between 1 and 6),
  add check ((period_start is null) = (period_end is null)),
  add check (period_start is null or period_start <= period_end),
  add unique (meal_plan_id, period_start);

-- Stavka: zamrznuto poreklo u trenutku kupovine.
alter table public.shopping_items
  add column purchase_provenance jsonb,
  add unique (id, household_id);

-- Ostava: potvrda količine i prijem kupljene stavke (jedan po kupovini).
alter table public.pantry_items
  add column confirmed_at timestamptz,
  add column source_shopping_item_id text,
  add unique (source_shopping_item_id),
  add unique (id, household_id),
  add foreign key (source_shopping_item_id, household_id)
    references public.shopping_items (id, household_id)
    on delete set null (source_shopping_item_id);

-- Izvor potražnje: planirani obrok ili samostalna priprema recepta. Id
-- samostalnog izvora je id pripreme.
create table public.shopping_sources (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  list_id text not null,
  kind text not null check (kind in ('planEntry', 'recipePreparation')),
  plan_entry_id text,
  recipe_snapshot jsonb,
  servings int check (servings between 1 and 20),
  recipe_id text,
  origin_key text,
  superseded_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id),
  unique (list_id, plan_entry_id),
  check (
    case kind
      when 'planEntry' then plan_entry_id is not null and recipe_snapshot is null
        and servings is null
      else plan_entry_id is null and coalesce(jsonb_typeof(recipe_snapshot) = 'object', false)
        and servings is not null
    end
  ),
  foreign key (list_id, household_id)
    references public.shopping_lists (id, household_id) on delete cascade,
  foreign key (plan_entry_id, household_id)
    references public.meal_plan_entries (id, household_id) on delete cascade,
  foreign key (recipe_id, household_id)
    references public.recipes (id, household_id) on delete set null (recipe_id)
);

-- Doprinos izvora stavci: izvor + sastojak + grupa jedinica, količina u
-- milionitim delovima osnovne jedinice (null samo za nepoznatu količinu).
create table public.shopping_contributions (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  shopping_item_id text,
  source_id text not null,
  ingredient_key text not null check (char_length(ingredient_key) > 0),
  unit_group text not null,
  base_unit text not null,
  micros bigint check (micros >= 0),
  name text not null,
  category text not null,
  notes jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id),
  unique (source_id, ingredient_key, unit_group),
  check ((micros is null) = (unit_group = 'unknown')),
  foreign key (shopping_item_id, household_id)
    references public.shopping_items (id, household_id) on delete set null (shopping_item_id),
  foreign key (source_id, household_id)
    references public.shopping_sources (id, household_id) on delete cascade
);

-- Potvrđena zaliha dodeljena doprinosu: iz ostave ili kupovine, tačno jedno.
create table public.supply_allocations (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  contribution_id text not null,
  pantry_item_id text,
  purchased_shopping_item_id text,
  supply_id text generated always as (coalesce(purchased_shopping_item_id, pantry_item_id)) stored,
  micros bigint check (micros >= 0),
  covers_whole_unknown boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (contribution_id, supply_id),
  check ((pantry_item_id is null) <> (purchased_shopping_item_id is null)),
  check (covers_whole_unknown or micros is not null),
  foreign key (contribution_id, household_id)
    references public.shopping_contributions (id, household_id) on delete cascade,
  foreign key (pantry_item_id, household_id)
    references public.pantry_items (id, household_id) on delete cascade,
  foreign key (purchased_shopping_item_id, household_id)
    references public.shopping_items (id, household_id) on delete cascade
);

-- Preuzimanje po (updated_at, id) unutar domaćinstva i kaskade.
create index shopping_sources_sync_idx on public.shopping_sources (household_id, updated_at, id);
create index shopping_contributions_sync_idx on public.shopping_contributions (household_id, updated_at, id);
create index supply_allocations_sync_idx on public.supply_allocations (household_id, updated_at, id);
create index shopping_sources_entry_idx on public.shopping_sources (plan_entry_id, household_id);
create index shopping_sources_recipe_idx on public.shopping_sources (recipe_id, household_id);
create index shopping_contributions_item_idx on public.shopping_contributions (shopping_item_id, household_id);
create index supply_allocations_pantry_idx on public.supply_allocations (pantry_item_id, household_id);
create index supply_allocations_purchase_idx on public.supply_allocations (purchased_shopping_item_id, household_id);

create trigger touch_updated_at before insert or update on public.shopping_sources
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.shopping_contributions
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.supply_allocations
  for each row execute function private.touch_updated_at('updated_by');

-- Brisanje ostavlja trag; dete obrisanog roditelja se ne vraća.
create trigger record_deletion after delete on public.shopping_sources
  for each row execute function private.record_deletion('shopping_source', 'id');
create trigger record_deletion after delete on public.shopping_contributions
  for each row execute function private.record_deletion('shopping_contribution', 'id');
create trigger record_deletion after delete on public.supply_allocations
  for each row execute function private.record_deletion('supply_allocation', 'id');

create trigger skip_if_deleted before insert on public.shopping_sources
  for each row execute function private.skip_if_deleted(
    'shopping_source', 'id', 'shopping_list', 'list_id', 'meal_plan_entry', 'plan_entry_id');
create trigger skip_if_deleted before insert on public.shopping_contributions
  for each row execute function private.skip_if_deleted(
    'shopping_contribution', 'id', 'shopping_source', 'source_id', 'shopping_item', 'shopping_item_id');
create trigger skip_if_deleted before insert on public.supply_allocations
  for each row execute function private.skip_if_deleted(
    'supply_allocation', 'id', 'shopping_contribution', 'contribution_id',
    'pantry_item', 'pantry_item_id', 'shopping_item', 'purchased_shopping_item_id');

-- RLS i izričita prava samo za authenticated.
alter table public.shopping_sources enable row level security;
alter table public.shopping_contributions enable row level security;
alter table public.supply_allocations enable row level security;

grant select, insert, update, delete on
  public.shopping_sources, public.shopping_contributions, public.supply_allocations
  to authenticated;

create policy "shopping_sources: members select" on public.shopping_sources
  for select to authenticated using (private.is_member(household_id));
create policy "shopping_sources: members insert" on public.shopping_sources
  for insert to authenticated with check (private.is_member(household_id));
create policy "shopping_sources: members update" on public.shopping_sources
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "shopping_sources: members delete" on public.shopping_sources
  for delete to authenticated using (private.is_member(household_id));
create policy "shopping_contributions: members select" on public.shopping_contributions
  for select to authenticated using (private.is_member(household_id));
create policy "shopping_contributions: members insert" on public.shopping_contributions
  for insert to authenticated with check (private.is_member(household_id));
create policy "shopping_contributions: members update" on public.shopping_contributions
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "shopping_contributions: members delete" on public.shopping_contributions
  for delete to authenticated using (private.is_member(household_id));
create policy "supply_allocations: members select" on public.supply_allocations
  for select to authenticated using (private.is_member(household_id));
create policy "supply_allocations: members insert" on public.supply_allocations
  for insert to authenticated with check (private.is_member(household_id));
create policy "supply_allocations: members update" on public.supply_allocations
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "supply_allocations: members delete" on public.supply_allocations
  for delete to authenticated using (private.is_member(household_id));
