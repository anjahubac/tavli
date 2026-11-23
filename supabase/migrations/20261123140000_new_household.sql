-- "Kreiraj novo domaćinstvo" iz profila.
--
-- Prelazak u novo domaćinstvo koristi isti tok kao pridruživanje (izbor
-- recepata, potvrda za poslednjeg člana, prenos fotografija, čekanje
-- sinhronizacije). Zato prepare_new_household samo napravi prazno
-- domaćinstvo sa nazivom i pozivnicom, a klijent zatim poziva
-- preview_household_join / household-join sa tim kodom. Prvi član praznog
-- domaćinstva postaje vlasnik. Domaćinstvo bez članova vidi samo server
-- (RLS ide preko članstva); kod zna samo osoba koja ga je napravila.

create table private.pending_new_households (
  user_id uuid primary key references auth.users (id) on delete cascade,
  household_id uuid not null unique references public.households (id) on delete cascade,
  created_at timestamptz not null default now()
);

revoke all on table private.pending_new_households
  from public, anon, authenticated, service_role;

-- Napušteno prazno domaćinstvo (odustajanje, novi pokušaj, brisanje naloga)
-- se briše zajedno sa svojim redom.
create function private.drop_unused_new_household()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.households h
   where h.id = old.household_id
     and not exists (
       select 1 from public.household_members m where m.household_id = h.id
     );
  return null;
end;
$$;

revoke all on function private.drop_unused_new_household()
  from public, anon, authenticated, service_role;

create trigger pending_new_households_drop_unused
  after delete on private.pending_new_households
  for each row execute function private.drop_unused_new_household();

-- Prvi član novog domaćinstva je vlasnik (prelazak inače upisuje `member`).
-- Niko drugi ne ulazi u novo domaćinstvo pre osobe koja ga je napravila.
create function private.own_new_household()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from private.pending_new_households p
     where p.household_id = new.household_id and p.user_id <> new.user_id
  ) then
    raise insufficient_privilege;
  end if;
  if exists (
    select 1 from private.pending_new_households p
     where p.household_id = new.household_id and p.user_id = new.user_id
  ) and not exists (
    select 1 from public.household_members m where m.household_id = new.household_id
  ) then
    new.role := 'owner';
  end if;
  return new;
end;
$$;

revoke all on function private.own_new_household()
  from public, anon, authenticated, service_role;

create trigger household_members_own_new_household
  before insert on public.household_members
  for each row execute function private.own_new_household();

-- Kada član postoji, domaćinstvo više nije "novo": red se briše, a okidač
-- iznad ga ne dira jer ima člana.
create function private.claim_new_household()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.pending_new_households p where p.household_id = new.household_id;
  return null;
end;
$$;

revoke all on function private.claim_new_household()
  from public, anon, authenticated, service_role;

create trigger household_members_claim_new_household
  after insert on public.household_members
  for each row execute function private.claim_new_household();

-- Pravi prazno domaćinstvo sa nazivom i vraća njegov kod. Prethodno
-- nekorišćeno novo domaćinstvo istog naloga se briše. Vraća `ready` (sa
-- `token`), `invalid_name` ili `rate_limited`.
create function public.prepare_new_household(name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  clean text := btrim(coalesce(name, ''));
  hid uuid;
  invite text;
begin
  if uid is null then raise insufficient_privilege; end if;
  if char_length(clean) not between 1 and 40 then
    return jsonb_build_object('status', 'invalid_name');
  end if;
  if not private.allow_household_join_request(true) then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  -- Isti redosled zaključavanja kao prelazak: prvo nalog.
  perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
  delete from private.pending_new_households p where p.user_id = uid;
  insert into public.households (name, created_by) values (clean, uid) returning id into hid;
  insert into private.household_invites (household_id) values (hid)
    returning token into invite;
  insert into private.pending_new_households (user_id, household_id) values (uid, hid);
  return jsonb_build_object('status', 'ready', 'token', invite);
end;
$$;

revoke all on function public.prepare_new_household(text) from public, anon;
grant execute on function public.prepare_new_household(text) to authenticated;
