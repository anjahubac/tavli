-- 009: publish revisions only. Business data still goes through the sync API.
create table public.household_sync_signals (
  id uuid primary key references public.households(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0)
);
create table public.account_sync_signals (
  id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0)
);
alter table public.household_sync_signals enable row level security;
alter table public.account_sync_signals enable row level security;
grant select on public.household_sync_signals, public.account_sync_signals to authenticated;
create policy household_sync_signals_read on public.household_sync_signals
  for select to authenticated using (private.is_member(id));
create policy account_sync_signals_read on public.account_sync_signals
  for select to authenticated using (id = (select auth.uid()));

create function public.household_realtime_eligible(expected_household uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case when private.is_member(expected_household) then (
    select count(*) >= 2
    from public.household_members
    where household_id = expected_household
  ) else null end;
$$;
revoke all on function public.household_realtime_eligible(uuid) from public, anon;
grant execute on function public.household_realtime_eligible(uuid) to authenticated;

insert into public.household_sync_signals(id) select id from public.households;
insert into public.account_sync_signals(id) select id from auth.users;

create function private.seed_household_sync_signal()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.household_sync_signals(id) values (new.id);
  return null;
end;
$$;
revoke all on function private.seed_household_sync_signal() from public, anon, authenticated;
create trigger seed_household_sync_signal after insert on public.households
  for each row execute function private.seed_household_sync_signal();

create function private.signal_membership_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  previous_household uuid;
  current_household uuid;
  previous_user uuid;
  current_user_id uuid;
begin
  if tg_op <> 'INSERT' then
    previous_household := old.household_id;
    previous_user := old.user_id;
  end if;
  if tg_op <> 'DELETE' then
    current_household := new.household_id;
    current_user_id := new.user_id;
  end if;
  -- Notify both sides at the threshold. No SELECT grants on membership
  -- details are changed. Sorted upserts keep account lock order stable.
  insert into public.account_sync_signals(id)
  select u.id
  from auth.users u
  where u.id in (
    select previous_user union select current_user_id
    union
    select m.user_id
    from public.household_members m
    where m.household_id in (previous_household, current_household)
      and 2 >= (select count(*) from public.household_members n where n.household_id = m.household_id)
  )
  order by u.id
  on conflict (id) do update set revision = account_sync_signals.revision + 1;
  return null;
end;
$$;
revoke all on function private.signal_membership_change() from public, anon, authenticated;
create trigger signal_membership_change after insert or update or delete on public.household_members
  for each row execute function private.signal_membership_change();

-- One bump per affected household per SQL statement, including bulk writes.
create function private.signal_household_changes()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.household_sync_signals s set revision = s.revision + 1
    where s.id in (select household_id from inserted_rows);
  elsif tg_op = 'DELETE' then
    update public.household_sync_signals s set revision = s.revision + 1
    where s.id in (select household_id from deleted_rows);
  else
    update public.household_sync_signals s set revision = s.revision + 1
    where s.id in (select household_id from inserted_rows union select household_id from deleted_rows);
  end if;
  return null;
end;
$$;
revoke all on function private.signal_household_changes() from public, anon, authenticated;
do $$
declare
  source text;
begin
  foreach source in array array[
    'shopping_lists', 'shopping_items', 'shopping_sources', 'shopping_contributions',
    'supply_allocations', 'pantry_items', 'pantry_consumptions', 'cooked_events',
    'meal_plans', 'meal_plan_entries', 'recipes', 'recipe_versions',
    'foods', 'food_aliases'
  ] loop
    execute format('create trigger realtime_insert after insert on public.%I referencing new table as inserted_rows for each statement execute function private.signal_household_changes()', source);
    execute format('create trigger realtime_update after update on public.%I referencing old table as deleted_rows new table as inserted_rows for each statement execute function private.signal_household_changes()', source);
    execute format('create trigger realtime_delete after delete on public.%I referencing old table as deleted_rows for each statement execute function private.signal_household_changes()', source);
  end loop;
end;
$$;

-- The household name is not part of the pull: the client reads it with the
-- membership check. A rename therefore notifies each member's personal signal,
-- which already triggers that check and then a pull. Row level: transition
-- tables cannot be combined with a column list, and a rename is one row.
-- Sorted upserts keep the account lock order stable.
create function private.signal_household_rename()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.account_sync_signals(id)
  select m.user_id from public.household_members m
  where m.household_id = new.id
  order by m.user_id
  on conflict (id) do update set revision = account_sync_signals.revision + 1;
  return null;
end;
$$;
revoke all on function private.signal_household_rename() from public, anon, authenticated;
create trigger realtime_rename after update of name on public.households
  for each row when (old.name is distinct from new.name)
  execute function private.signal_household_rename();

-- Realtime cannot enforce row visibility after a row was physically deleted.
-- Publish only updates so cascade deletion never reveals a former scope ID.
do $$
begin
  if exists (
    select 1 from pg_catalog.pg_publication_tables where pubname = 'supabase_realtime'
  ) then
    raise exception 'realtime publication contains tables outside spec 009';
  end if;
end;
$$;
alter publication supabase_realtime set (publish = 'update');
alter publication supabase_realtime add table public.household_sync_signals, public.account_sync_signals;
