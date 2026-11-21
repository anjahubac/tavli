-- 021: obrok skuvan. Zapis svakog označavanja (ko, kada, porcije), potrošnja
-- iz ostave po zapisu i vreme ručnog brojanja količine. Samo dodaje;
-- postojeći redovi ostaju (već skuvani obroci nemaju zapis ni potrošnju).

-- Ostava: kada je osoba poslednji put ručno upisala količinu.
alter table public.pantry_items
  add column quantity_set_at timestamptz;

-- Jedno označavanje obroka kao skuvanog. Poništavanje upisuje undone_at;
-- zapis se ne briše, a ponovno kuvanje je nov zapis.
create table public.cooked_events (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  plan_entry_id text not null,
  meal_date date not null,
  meal_type text not null check (char_length(meal_type) between 1 and 32),
  actor_user_id uuid not null,
  servings int not null check (servings between 1 and 20),
  cooked_at timestamptz not null,
  undone_at timestamptz,
  undo_reason text check (undo_reason in ('user')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (id, household_id),
  check ((undone_at is null) = (undo_reason is null)),
  foreign key (plan_entry_id, household_id)
    references public.meal_plan_entries (id, household_id) on delete cascade
);

-- Koliko je jedno kuvanje uzelo iz jedne stavke ostave, u milionitim delovima
-- osnovne jedinice stavke. Isti par zapis + stavka je jedan red.
create table public.pantry_consumptions (
  id text primary key check (char_length(id) between 1 and 64),
  household_id uuid not null references public.households (id) on delete cascade,
  event_id text not null,
  pantry_item_id text not null,
  base_unit text not null check (char_length(base_unit) between 1 and 32),
  micros bigint not null check (micros > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  unique (event_id, pantry_item_id),
  foreign key (event_id, household_id)
    references public.cooked_events (id, household_id) on delete cascade,
  foreign key (pantry_item_id, household_id)
    references public.pantry_items (id, household_id) on delete cascade
);

create index cooked_events_sync_idx on public.cooked_events (household_id, updated_at, id);
create index cooked_events_entry_idx on public.cooked_events (plan_entry_id, household_id);
create index pantry_consumptions_sync_idx on public.pantry_consumptions (household_id, updated_at, id);
create index pantry_consumptions_item_idx on public.pantry_consumptions (pantry_item_id, household_id);

-- Zapis se samo poništava: šta je skuvano, ko i kada ostaje kako je upisano,
-- a upisano poništavanje se ne vraća (zakasnelo slanje starog reda).
create or replace function private.keep_cooked_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.plan_entry_id := old.plan_entry_id;
  new.meal_date := old.meal_date;
  new.meal_type := old.meal_type;
  new.actor_user_id := old.actor_user_id;
  new.servings := old.servings;
  new.cooked_at := old.cooked_at;
  if old.undone_at is not null then
    new.undone_at := old.undone_at;
    new.undo_reason := old.undo_reason;
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_cooked_event() from public, anon, authenticated;

create trigger keep_cooked_event before update on public.cooked_events
  for each row execute function private.keep_cooked_event();

create trigger touch_updated_at before insert or update on public.cooked_events
  for each row execute function private.touch_updated_at('updated_by');
create trigger touch_updated_at before insert or update on public.pantry_consumptions
  for each row execute function private.touch_updated_at('updated_by');

create trigger record_deletion after delete on public.cooked_events
  for each row execute function private.record_deletion('cooked_event', 'id');
create trigger record_deletion after delete on public.pantry_consumptions
  for each row execute function private.record_deletion('pantry_consumption', 'id');

create trigger skip_if_deleted before insert on public.cooked_events
  for each row execute function private.skip_if_deleted(
    'cooked_event', 'id', 'meal_plan_entry', 'plan_entry_id');
create trigger skip_if_deleted before insert on public.pantry_consumptions
  for each row execute function private.skip_if_deleted(
    'pantry_consumption', 'id', 'cooked_event', 'event_id', 'pantry_item', 'pantry_item_id');

-- RLS i izričita prava samo za authenticated. Ko je kuvao mora biti član
-- istog domaćinstva. (Slanje je upsert, pa uslov ne sme da traži da je to
-- baš prijavljena osoba: i drugi član šalje isti red kad poništi kuvanje.)
alter table public.cooked_events enable row level security;
alter table public.pantry_consumptions enable row level security;

grant select, insert, update, delete on
  public.cooked_events, public.pantry_consumptions
  to authenticated;

create policy "cooked_events: members select" on public.cooked_events
  for select to authenticated using (private.is_member(household_id));
create policy "cooked_events: members insert" on public.cooked_events
  for insert to authenticated
  with check (
    private.is_member(household_id)
    and exists (
      select 1 from public.household_members m
      where m.household_id = cooked_events.household_id
        and m.user_id = cooked_events.actor_user_id
    )
  );
create policy "cooked_events: members update" on public.cooked_events
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "cooked_events: members delete" on public.cooked_events
  for delete to authenticated using (private.is_member(household_id));
create policy "pantry_consumptions: members select" on public.pantry_consumptions
  for select to authenticated using (private.is_member(household_id));
create policy "pantry_consumptions: members insert" on public.pantry_consumptions
  for insert to authenticated with check (private.is_member(household_id));
create policy "pantry_consumptions: members update" on public.pantry_consumptions
  for update to authenticated
  using (private.is_member(household_id)) with check (private.is_member(household_id));
create policy "pantry_consumptions: members delete" on public.pantry_consumptions
  for delete to authenticated using (private.is_member(household_id));
