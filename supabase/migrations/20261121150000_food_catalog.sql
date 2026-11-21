-- 018 / D1-005: katalog namirnica (specs/018-ingredient-catalog/data-model.md).
-- Jedna tabela namirnica i jedna tabela aliasa; household_id null = deljeni
-- pregledani katalog (piše ga samo migracija ili service_role), inače kućni
-- red domaćinstva. Samo dodaje; ništa ga još ne čita.

create table public.foods (
  id text primary key check (
    char_length(id) between 1 and 64
    and id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ),
  household_id uuid references public.households (id) on delete cascade,
  slug text not null check (char_length(slug) between 1 and 120),
  name text not null check (char_length(name) between 1 and 120),
  category text not null check (char_length(category) between 1 and 64),
  base_unit text not null check (base_unit in ('piece', 'gram', 'milliliter')),
  source text check (char_length(source) <= 500),
  reviewed_at timestamptz,
  -- Povlači se samo deljena namirnica; kućna se briše (sa tragom).
  withdrawn_at timestamptz check (withdrawn_at is null or household_id is null),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

-- Slug je jedinstven samo u deljenom katalogu. Kućni namerno nema jedinstven
-- ključ: dva uređaja offline mogu da naprave istu namirnicu sa različitim id,
-- pa bi drugo slanje trajno palo (isto pravilo kao za kućne aliase).
create unique index foods_shared_slug_key on public.foods (slug) where household_id is null;

create table public.food_aliases (
  id text primary key check (
    char_length(id) between 1 and 64
    and id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ),
  -- Jedan strani ključ: složeni (id, household_id) ne može da izrazi deljenu
  -- namirnicu. Da li alias sme na tu namirnicu proverava okidač ispod.
  food_id text not null references public.foods (id) on delete cascade,
  household_id uuid references public.households (id) on delete cascade,
  alias text not null check (char_length(alias) between 1 and 120),
  -- Vrednost postojećeg ingredientKey (odluka D4), čuva se kako je poslata.
  alias_normalized text not null check (char_length(alias_normalized) between 1 and 120),
  withdrawn_at timestamptz check (withdrawn_at is null or household_id is null),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);

-- Deljeni alias je jedinstven dok je aktivan; kućni namerno nema jedinstven
-- ključ (zamena = upis pa brisanje, data-model.md „Replacing a household alias“).
create unique index food_aliases_shared_active_key
  on public.food_aliases (alias_normalized)
  where household_id is null and withdrawn_at is null;

create index foods_sync_idx on public.foods (household_id, updated_at, id);
create index foods_shared_sync_idx on public.foods (updated_at, id) where household_id is null;
create index food_aliases_sync_idx on public.food_aliases (household_id, updated_at, id);
create index food_aliases_shared_sync_idx on public.food_aliases (updated_at, id)
  where household_id is null;
create index food_aliases_food_idx on public.food_aliases (food_id);

-- Vlasništvo se ne menja ni za jednu ulogu (odluka D8). Prenos u deljeni
-- katalog je nov deljeni red, ne izmena household_id.
create or replace function private.keep_food_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
     or new.household_id is distinct from old.household_id
     or (tg_table_name = 'food_aliases'
         and (to_jsonb(new) ->> 'food_id') is distinct from (to_jsonb(old) ->> 'food_id')) then
    raise exception 'vlasništvo zapisa kataloga se ne menja'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

-- Deljeni alias pokazuje samo na deljenu namirnicu; kućni na deljenu ili na
-- namirnicu istog domaćinstva (odluka D2). Nov kućni alias ne sme na povučenu
-- namirnicu (D9); postojeći red (ponovno slanje je upsert) ostaje i šalje se
-- dalje. Okidač radi pre skip_if_deleted (redosled po imenu), pa sam tiho
-- preskače alias namirnice koju je obrisalo isto domaćinstvo: brisanje
-- pobeđuje. security definer: tuđa namirnica, postojeća ili obrisana, se vidi
-- da bi se odbila, a odgovor je isti kao za nepostojeću.
create or replace function private.check_food_alias()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  f public.foods%rowtype;
begin
  select * into f from public.foods where id = new.food_id;
  if not found and new.household_id is not null and exists (
    select 1 from public.deletions d
    where d.entity = 'food' and d.record_id = new.food_id
      and d.household_id = new.household_id
  ) then
    return null;
  end if;
  if not found
     or (f.household_id is not null
         and f.household_id is distinct from new.household_id)
     or (tg_op = 'INSERT' and new.household_id is not null and f.withdrawn_at is not null
         and not exists (select 1 from public.food_aliases a where a.id = new.id)) then
    raise exception 'alias ne može da pokazuje na tu namirnicu'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_food_owner() from public, anon, authenticated;
revoke execute on function private.check_food_alias() from public, anon, authenticated;

create trigger keep_food_owner before update on public.foods
  for each row execute function private.keep_food_owner();
create trigger keep_food_owner before update on public.food_aliases
  for each row execute function private.keep_food_owner();
create trigger check_food_alias before insert or update on public.food_aliases
  for each row execute function private.check_food_alias();

create trigger touch_updated_at before insert or update on public.foods
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.food_aliases
  for each row execute function private.touch_updated_at('updated_by');

-- Trag brisanja samo za kućne redove: deljeni se ne briše nego povlači, a
-- deletions traži vlasnika (domaćinstvo ili osobu).
create trigger record_deletion after delete on public.foods
  for each row when (old.household_id is not null)
  execute function private.record_deletion('food', 'id');
create trigger record_deletion after delete on public.food_aliases
  for each row when (old.household_id is not null)
  execute function private.record_deletion('food_alias', 'id');

create trigger skip_if_deleted before insert on public.foods
  for each row execute function private.skip_if_deleted('food', 'id');
create trigger skip_if_deleted before insert on public.food_aliases
  for each row execute function private.skip_if_deleted('food_alias', 'id', 'food', 'food_id');

-- RLS: deljeno čita svaki prijavljen korisnik, kućno samo članovi. Pisanje
-- iz klijenta samo za kućne redove sopstvenog domaćinstva; is_member(null)
-- je false, pa deljeni red ne može da se doda, menja ni briše.
alter table public.foods enable row level security;
alter table public.food_aliases enable row level security;

grant select, insert, update, delete on public.foods, public.food_aliases to authenticated;

create policy "foods: shared or members select" on public.foods
  for select to authenticated
  using (household_id is null or private.is_member(household_id));
create policy "foods: members insert" on public.foods
  for insert to authenticated with check (private.is_member(household_id));
create policy "foods: members update" on public.foods
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "foods: members delete" on public.foods
  for delete to authenticated using (private.is_member(household_id));

create policy "food_aliases: shared or members select" on public.food_aliases
  for select to authenticated
  using (household_id is null or private.is_member(household_id));
create policy "food_aliases: members insert" on public.food_aliases
  for insert to authenticated with check (private.is_member(household_id));
create policy "food_aliases: members update" on public.food_aliases
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "food_aliases: members delete" on public.food_aliases
  for delete to authenticated using (private.is_member(household_id));
