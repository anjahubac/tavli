-- Pomoćne funkcije za pgTAP testove (šema `tests`, samo u lokalnoj bazi).
-- Fajl se izvršava prvi (abecedni red) i ostaje u bazi do `supabase db reset`.

create extension if not exists pgtap with schema extensions;

create schema if not exists tests;
grant usage on schema tests to anon, authenticated, service_role;

-- Novi auth korisnik; okidač pravi profil, domaćinstvo i članstvo.
create or replace function tests.create_user(email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := gen_random_uuid();
begin
  insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', email,
          '{"provider":"email","providers":["email"]}', '{}', now(), now());
  return uid;
end;
$$;

-- Ostatak transakcije radi kao prijavljeni korisnik (RLS važi).
create or replace function tests.authenticate_as(uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function tests.authenticate_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end;
$$;

-- Nazad na postgres (vlasnik tabela, bez RLS-a).
create or replace function tests.clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Domaćinstvo korisnika (jedno u 006a).
create or replace function tests.household_of(uid uuid)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select household_id from public.household_members where user_id = uid limit 1;
$$;

-- Broj redova koje upit menja (UPDATE/DELETE ... RETURNING 1).
create or replace function tests.affected(sql text)
returns bigint
language plpgsql
as $$
declare
  n bigint;
begin
  execute 'with x as (' || sql || ' returning 1) select count(*) from x' into n;
  return n;
end;
$$;

grant execute on all functions in schema tests to anon, authenticated, service_role;

select plan(1);
select has_function('tests', 'authenticate_as', array['uuid'], 'pomoćne funkcije postoje');
select * from finish();
