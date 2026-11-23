-- Korak "Tvoje domaćinstvo" posle imena, naziv domaćinstva i spisak članova.
--
-- Okidač handle_new_user i dalje pravi lično domaćinstvo, pa svaki nalog
-- uvek ima tačno jedno članstvo. Novi nalog ga u prvom koraku imenuje ili
-- ga zamenjuje pridruživanjem; do tada je household_setup_done false.

-- Postojeći nalozi su već prošli prijavu: kolona za njih ostaje true, a
-- podrazumevana vrednost za nove profile je false.
alter table public.profiles
  add column household_setup_done boolean not null default true;
alter table public.profiles
  alter column household_setup_done set default false;

-- Pridruživanje (uloga member) završava korak bez posebnog poziva, u istoj
-- transakciji kao prelazak.
create function private.finish_household_setup_on_join()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role = 'member' then
    update public.profiles set household_setup_done = true
      where id = new.user_id and not household_setup_done;
  end if;
  return null;
end;
$$;

revoke all on function private.finish_household_setup_on_join()
  from public, anon, authenticated, service_role;

create trigger household_members_finish_setup
  after insert on public.household_members
  for each row execute function private.finish_household_setup_on_join();

-- Vlasnik menja naziv svog domaćinstva; isti poziv završava korak
-- "Tvoje domaćinstvo". Vraća `renamed`, `invalid_name` ili `not_allowed`.
create function public.rename_household(name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  clean text := btrim(coalesce(name, ''));
begin
  if uid is null then raise insufficient_privilege; end if;
  if char_length(clean) not between 1 and 40 then
    return jsonb_build_object('status', 'invalid_name');
  end if;
  select m.household_id into hid from public.household_members m
    where m.user_id = uid and m.role = 'owner';
  if hid is null then
    return jsonb_build_object('status', 'not_allowed');
  end if;
  -- Isti red zaključava prelazak i uklanjanje, pa se vlasnik proverava
  -- posle zaključavanja.
  perform 1 from public.households h where h.id = hid for update;
  if not exists (
    select 1 from public.household_members m
      where m.household_id = hid and m.user_id = uid and m.role = 'owner'
  ) then
    return jsonb_build_object('status', 'not_allowed');
  end if;
  update public.households h set name = clean where h.id = hid;
  update public.profiles p set household_setup_done = true
    where p.id = uid and not p.household_setup_done;
  return jsonb_build_object('status', 'renamed', 'household_id', hid, 'name', clean);
end;
$$;

revoke all on function public.rename_household(text) from public, anon;
grant execute on function public.rename_household(text) to authenticated;

-- Članovi sopstvenog domaćinstva: samo ime i uloga, bez e-pošte. Profil
-- drugog člana inače nije čitljiv (RLS: samo svoj).
create function public.household_members_overview()
returns table (user_id uuid, display_name text, role text, joined_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select m.user_id, p.display_name, m.role, m.joined_at
    from public.household_members mine
    join public.household_members m on m.household_id = mine.household_id
    left join public.profiles p on p.id = m.user_id
   where mine.user_id = auth.uid()
   order by m.joined_at, m.user_id;
$$;

revoke all on function public.household_members_overview() from public, anon;
grant execute on function public.household_members_overview() to authenticated;
