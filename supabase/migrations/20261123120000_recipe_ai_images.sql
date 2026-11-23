-- TRELLO-130: AI slike za recepte koje je napravio AI.
-- Funkcija ai-gateway (zadatak `recipe_image`) pravi sliku iz opisa jela,
-- čuva je u `recipe-photos/{household_id}/` i vraća ime fajla; aplikacija
-- upisuje putanju u recept kroz red za slanje.

-- Opis slike (engleski, ~50 reči) i ko je postavio sliku: 'ai' ili 'user';
-- null = nepoznato (stari recepti, stari klijenti). Postojeće RLS politike i
-- grant na public.recipes pokrivaju nove kolone.
alter table public.recipes
  add column image_description text
    check (image_description is null or char_length(image_description) <= 1000),
  add column image_source text check (image_source in ('ai', 'user'));

-- AI slika nikad ne zamenjuje sliku koju nije napravio AI, ni sa zastarelog
-- uređaja; slika bez izvora je starija od ove kolone, dakle korisnikova.
-- Izmena bez opisa ili izvora ne briše već sačuvane vrednosti.
create or replace function private.keep_user_recipe_photo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.image_description := coalesce(new.image_description, old.image_description);
  if new.image_source = 'ai' and old.image_path is not null
     and old.image_source is distinct from 'ai' then
    new.image_path := old.image_path;
    new.image_source := old.image_source;
  elsif new.image_source is null
     and new.image_path is not distinct from old.image_path then
    new.image_source := old.image_source;
  end if;
  return new;
end;
$$;

revoke execute on function private.keep_user_recipe_photo() from public, anon, authenticated;

create trigger keep_user_recipe_photo before update on public.recipes
  for each row execute function private.keep_user_recipe_photo();

-- Jedan red po receptu, korisniku i danu (UTC). Ponovljen zahtev za isti
-- recept istog dana ne troši novi dnevni limit, ali povećava attempts (i taj
-- broj je ograničen). Bez opisa, slike i imena modela.
create table public.ai_image_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  recipe_id text check (recipe_id is null or char_length(recipe_id) between 1 and 64),
  day date not null,
  attempts int not null default 1 check (attempts >= 1),
  created_at timestamptz not null default now(),
  unique (user_id, recipe_id, day)
);

create index ai_image_requests_day_idx on public.ai_image_requests (day);

-- Brisanje naloga: FK briše vezu sa korisnikom, a ovaj okidač i id recepta.
-- Red ostaje samo kao anoniman zajednički brojač i nestaje posle 2 dana.
create or replace function private.forget_ai_image_request()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is null then
    new.recipe_id := null;
  end if;
  return new;
end;
$$;

revoke execute on function private.forget_ai_image_request() from public, anon, authenticated;

create trigger forget_ai_image_request before update of user_id on public.ai_image_requests
  for each row execute function private.forget_ai_image_request();

-- RLS bez politika i bez grantova: čita i piše samo funkcija ispod.
alter table public.ai_image_requests enable row level security;
revoke all on public.ai_image_requests from public, anon, authenticated;

-- Proverava i troši limite slika u jednoj transakciji (globalno
-- zaključavanje, kao ai_reserve). Domaćinstvo je ono čiji je korisnik član;
-- aplikacija ga ne šalje.
--
-- Vraća {"id": uuid, "household_id": uuid}, {"limit": "user"|"project",
-- "retry_after_seconds": n} ili {"error": "no_household"}. Odbijen zahtev ne
-- upisuje ništa. Dan se menja u 00:00 UTC (kao besplatni limit Cloudflare-a).
create or replace function public.ai_image_reserve(
  p_user_id uuid,
  p_recipe_id text,
  p_user_limit int,
  p_project_limit int,
  p_attempt_limit int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz;
  v_day date;
  v_until_midnight int;
  v_household uuid;
  v_id uuid;
  v_attempts int;
  v_count int;
begin
  if p_user_id is null or p_recipe_id is null
     or p_recipe_id !~ '^[A-Za-z0-9_-]{1,64}$'
     or p_user_limit is null or p_user_limit < 1
     or p_project_limit is null or p_project_limit < 1
     or p_attempt_limit is null or p_attempt_limit < 1 then
    raise exception 'ai_image_reserve: neispravan ulaz' using errcode = '22023';
  end if;

  select m.household_id into v_household
  from public.household_members m
  where m.user_id = p_user_id
  order by m.joined_at desc
  limit 1;
  if v_household is null then
    return jsonb_build_object('error', 'no_household');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('ai_image_reserve', 0));

  v_now := clock_timestamp();
  v_day := (v_now at time zone 'utc')::date;
  v_until_midnight := greatest(1, ceil(extract(epoch from (
    ((v_day + 1)::timestamp at time zone 'utc') - v_now
  )))::int);

  delete from public.ai_image_requests where day < v_day - 2;

  select r.id, r.attempts into v_id, v_attempts
  from public.ai_image_requests r
  where r.user_id = p_user_id and r.recipe_id = p_recipe_id and r.day = v_day;
  if found and v_attempts >= p_attempt_limit then
    return jsonb_build_object('limit', 'user', 'retry_after_seconds', v_until_midnight);
  end if;

  -- Zajednički limit štiti besplatnu kvotu, pa broji svaki poziv provajdera
  -- (i ponovljene), ne samo različite recepte.
  select coalesce(sum(r.attempts), 0) into v_count
  from public.ai_image_requests r where r.day = v_day;
  if v_count >= p_project_limit then
    return jsonb_build_object('limit', 'project', 'retry_after_seconds', v_until_midnight);
  end if;

  if v_id is not null then
    update public.ai_image_requests set attempts = attempts + 1 where id = v_id;
    return jsonb_build_object('id', v_id, 'household_id', v_household);
  end if;

  select count(*) into v_count from public.ai_image_requests
  where user_id = p_user_id and day = v_day;
  if v_count >= p_user_limit then
    return jsonb_build_object('limit', 'user', 'retry_after_seconds', v_until_midnight);
  end if;

  insert into public.ai_image_requests (user_id, recipe_id, day)
  values (p_user_id, p_recipe_id, v_day)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'household_id', v_household);
end;
$$;

revoke execute on function public.ai_image_reserve(uuid, text, int, int, int)
  from public, anon, authenticated;
grant execute on function public.ai_image_reserve(uuid, text, int, int, int) to service_role;
