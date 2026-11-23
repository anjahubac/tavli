-- D3-006: svaki član domaćinstva (ne samo vlasnik) deli istu pozivnicu, a
-- vlasnik može da je zameni novom. Pozivnica je i dalje jedna po domaćinstvu.
create or replace function public.household_invite_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  invite text;
begin
  if uid is null then raise insufficient_privilege; end if;
  select m.household_id into hid from public.household_members m
    where m.user_id = uid;
  if hid is null then raise insufficient_privilege; end if;
  -- Koristi isti red kao potvrda prelaska, pa ponovo proveri članstvo.
  perform 1 from public.households h where h.id = hid for key share;
  if not exists (
    select 1 from public.household_members m
      where m.household_id = hid and m.user_id = uid
  ) then
    raise insufficient_privilege;
  end if;
  select i.token into invite from private.household_invites i where i.household_id = hid;
  if found then return invite; end if;

  for attempt in 1..3 loop
    insert into private.household_invites (household_id) values (hid)
      on conflict do nothing;
    select i.token into invite from private.household_invites i where i.household_id = hid;
    if found then return invite; end if;
  end loop;
  raise exception 'Invite code generation failed';
end;
$$;

revoke all on function public.household_invite_token() from public, anon;
grant execute on function public.household_invite_token() to authenticated;

-- Vlasnik zamenjuje pozivnicu: stari kod, QR i link odmah prestaju da rade,
-- a članstva ostaju. Vraća novi kod; bez uloge vlasnika SQLSTATE 42501.
create function public.regenerate_household_invite()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  invite text;
begin
  if uid is null then raise insufficient_privilege; end if;
  select m.household_id into hid from public.household_members m
    where m.user_id = uid and m.role = 'owner';
  if hid is null then raise insufficient_privilege; end if;
  -- Isključivo zaključavanje čeka prelaske u toku (oni drže key share), pa
  -- se vlasnik proverava tek posle zaključavanja.
  perform 1 from public.households h where h.id = hid for update;
  if not exists (
    select 1 from public.household_members m
      where m.household_id = hid and m.user_id = uid and m.role = 'owner'
  ) then
    raise insufficient_privilege;
  end if;
  delete from private.household_invites i where i.household_id = hid;
  for attempt in 1..3 loop
    insert into private.household_invites (household_id) values (hid)
      on conflict do nothing;
    select i.token into invite from private.household_invites i where i.household_id = hid;
    if found then return invite; end if;
  end loop;
  raise exception 'Invite code generation failed';
end;
$$;

revoke all on function public.regenerate_household_invite() from public, anon;
grant execute on function public.regenerate_household_invite() to authenticated;
