-- Server zna razliku između uklanjanja i sopstvenog prelaska: uklanjanje upiše
-- zapis, a drugi uređaj ga preuzima jednom. Bez toga klijent pogađa iz uloge,
-- a "Kreiraj novo domaćinstvo" takođe daje ulogu vlasnika.
create table private.household_removals (
  user_id uuid primary key references auth.users (id) on delete cascade,
  household_id uuid not null,
  removed_at timestamptz not null default now()
);

revoke all on table private.household_removals
  from public, anon, authenticated, service_role;

-- Isto kao ranije, uz zapis o uklanjanju. Poslednje uklanjanje zamenjuje
-- prethodno; zapis za drugo domaćinstvo se ne poklapa pri preuzimanju.
create or replace function public.remove_household_member(member_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  new_home uuid;
begin
  if uid is null then raise insufficient_privilege; end if;
  if member_id is null or member_id = uid then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(member_id::text, 0));
  select m.household_id into hid from public.household_members m
   where m.user_id = uid and m.role = 'owner';
  if hid is null then return jsonb_build_object('status', 'not_allowed'); end if;
  perform 1 from public.households h where h.id = hid for update;

  -- Ponovo, posle zaključavanja: vlasništvo se možda promenilo u međuvremenu.
  if not exists (
    select 1 from public.household_members m
     where m.household_id = hid and m.user_id = uid and m.role = 'owner'
  ) then
    return jsonb_build_object('status', 'not_allowed');
  end if;

  delete from public.household_members m
   where m.household_id = hid and m.user_id = member_id;
  if not found then return jsonb_build_object('status', 'not_allowed'); end if;

  insert into public.households (created_by) values (member_id) returning id into new_home;
  insert into public.household_members (household_id, user_id, role)
    values (new_home, member_id, 'owner');
  insert into private.household_removals (user_id, household_id)
    values (member_id, hid)
    on conflict (user_id) do update
      set household_id = excluded.household_id, removed_at = now();
  return jsonb_build_object('status', 'removed');
end;
$$;

-- Uređaj koji je primetio promenu domaćinstva pita da li je to uklanjanje iz
-- `previous_household`. Zapis se troši, pa se obaveštenje prikazuje jednom.
create function public.take_household_removal(previous_household uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise insufficient_privilege; end if;
  delete from private.household_removals r
   where r.user_id = uid and r.household_id = previous_household;
  return found;
end;
$$;

revoke all on function public.take_household_removal(uuid) from public, anon;
grant execute on function public.take_household_removal(uuid) to authenticated;
