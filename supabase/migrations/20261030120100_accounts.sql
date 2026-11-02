-- 006a: profil, domaćinstvo i članstvo; pravi ih okidač na auth.users.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text check (
    display_name is null or char_length(btrim(display_name)) between 1 and 40
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Moje domaćinstvo',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'owner' check (role in ('owner')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index household_members_user_id_idx on public.household_members (user_id);

create trigger touch_updated_at before insert or update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger touch_updated_at before insert or update on public.households
  for each row execute function private.touch_updated_at();

-- Da li je prijavljena osoba član domaćinstva. security definer: čita
-- household_members bez RLS-a (inače bi politika na toj tabeli zvala samu sebe).
create or replace function private.is_member(hid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members m
    where m.household_id = hid
      and m.user_id = (select auth.uid())
  );
$$;

revoke execute on function private.is_member(uuid) from public, anon;
grant execute on function private.is_member(uuid) to authenticated;

-- Prvi put kad se nalog napravi: profil, "Moje domaćinstvo" i članstvo
-- (vlasnik), u istoj transakciji. Tačno jednom po nalogu.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  hid uuid;
begin
  insert into public.profiles (id, email)
  values (new.id, lower(coalesce(new.email, '')))
  on conflict (id) do nothing;

  if not exists (select 1 from public.household_members m where m.user_id = new.id) then
    insert into public.households (created_by) values (new.id) returning id into hid;
    insert into public.household_members (household_id, user_id, role)
    values (hid, new.id, 'owner');
  end if;
  return new;
end;
$$;

revoke execute on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();
