-- Vlasnik uklanja člana; uklonjeni u istoj transakciji dobija novo lično
-- domaćinstvo. Svaki nalog sa profilom uvek ima tačno jedno članstvo.

-- "Najviše jedno" već čuva household_members_one_per_user_idx. Ovo čuva
-- "najmanje jedno" na kraju transakcije, pa prelazak i brisanje naloga
-- smeju privremeno da ostanu bez članstva.
create function private.require_household_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
begin
  -- Odvojene grane: polje iz OLD/NEW se razrešava tek kad se grana izvrši.
  if tg_table_name = 'profiles' then
    uid := new.id;
  else
    uid := old.user_id;
  end if;
  if exists (select 1 from public.profiles p where p.id = uid)
     and not exists (select 1 from public.household_members m where m.user_id = uid) then
    raise exception 'account % has no household membership', uid
      using errcode = '23514';
  end if;
  return null;
end;
$$;

revoke all on function private.require_household_membership()
  from public, anon, authenticated, service_role;

create constraint trigger household_members_require_membership
  after delete on public.household_members
  deferrable initially deferred
  for each row execute function private.require_household_membership();

create constraint trigger profiles_require_membership
  after insert on public.profiles
  deferrable initially deferred
  for each row execute function private.require_household_membership();

-- Isti redosled zaključavanja kao kod prelaska: nalog člana, pa domaćinstvo.
-- Greške su generičke da pozivalac ne sazna tuđa članstva.
create function public.remove_household_member(member_id uuid)
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
  return jsonb_build_object('status', 'removed');
end;
$$;

revoke all on function public.remove_household_member(uuid) from public, anon;
grant execute on function public.remove_household_member(uuid) to authenticated;
