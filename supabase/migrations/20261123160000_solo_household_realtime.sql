-- Every verified household can have multiple devices, even with one member.
create or replace function public.household_realtime_eligible(expected_household uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case when private.is_member(expected_household) then true end;
$$;

-- Notify only the owner of private changes. Each statement increments at
-- most one revision per affected account, including cascaded deletions.
create function private.signal_personal_changes()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.account_sync_signals s set revision = revision + 1
    where s.id in (select user_id from inserted_rows);
  elsif tg_op = 'DELETE' then
    update public.account_sync_signals s set revision = revision + 1
    where s.id in (select user_id from deleted_rows);
  else
    update public.account_sync_signals s set revision = revision + 1
    where s.id in (select user_id from inserted_rows union select user_id from deleted_rows);
  end if;
  return null;
end;
$$;
revoke all on function private.signal_personal_changes() from public, anon, authenticated;
do $$
declare
  source text;
begin
  foreach source in array array['ratings', 'taste_profiles', 'user_favorites', 'user_allergen_selections'] loop
    execute format('create trigger realtime_insert after insert on public.%I referencing new table as inserted_rows for each statement execute function private.signal_personal_changes()', source);
    execute format('create trigger realtime_update after update on public.%I referencing old table as deleted_rows new table as inserted_rows for each statement execute function private.signal_personal_changes()', source);
    execute format('create trigger realtime_delete after delete on public.%I referencing old table as deleted_rows for each statement execute function private.signal_personal_changes()', source);
  end loop;
end;
$$;
