-- 015 slice 2: evidencija poziva ugrađenog AI-ja i atomska rezervacija limita
-- (specs/015-ai-server-gateway/contracts/ai-gateway-contract.md, „Reservation“).
-- Funkcija ai-gateway zove ai_reserve pre svakog poziva provajdera i ai_release
-- posle njega. Samo service_role; prijavljen korisnik i anon nemaju pristup.

-- Jedan red po pozivu provajdera: samo vrsta i vremena, bez teksta zahteva,
-- odgovora modela i imena modela. user_id postaje null kad se nalog briše, pa
-- red ostaje u zajedničkom brojaču i nestaje sa čišćenjem posle 2 dana.
create table public.ai_calls (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  kind text not null check (kind in ('vision', 'text')),
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

create index ai_calls_user_started_idx on public.ai_calls (user_id, started_at);
create index ai_calls_started_idx on public.ai_calls (started_at);

-- RLS bez politika i bez grantova: tabelu čita i piše samo funkcija ispod.
alter table public.ai_calls enable row level security;
revoke all on public.ai_calls from public, anon, authenticated;

-- Svi limiti se proveravaju i troše u jednoj transakciji. Globalno
-- (transakciono) zaključavanje serijalizuje rezervacije, pa paralelni zahtevi
-- ne mogu svi da prođu proveru pa svi da potroše. Svaka rezervacija je nekoliko
-- čitanja iz indeksa i jedan upis; za veličinu tima to je dovoljno.
--
-- Redosled provere: istovremeni, minutni, dnevni (po vrsti), zajednički.
-- Vraća {"id": uuid} ili {"limit": ..., "retry_after_seconds": n}; neuspela
-- rezervacija ne upisuje ništa. Red u letu stariji od 90 s ne blokira
-- istovremeni limit (srušena funkcija ne sme da zaključa korisnika), ali se
-- i dalje računa u minutni i dnevni.
create or replace function public.ai_reserve(
  p_user_id uuid,
  p_kind text,
  p_daily_limit int,
  p_minute_limit int,
  p_concurrent_limit int,
  p_global_limit int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz;
  v_day_start timestamptz;
  v_until_midnight int;
  v_count int;
  v_free timestamptz;
  v_id uuid;
begin
  -- Prazna vrednost ne sme da prođe: poređenje sa null nije istina, pa bi
  -- prazan limit tiho isključio svoju proveru (a zajednički je ograničavač troška).
  if p_user_id is null or p_kind is null or p_kind not in ('vision', 'text')
     or p_daily_limit is null or p_daily_limit < 1
     or p_minute_limit is null or p_minute_limit < 1
     or p_concurrent_limit is null or p_concurrent_limit < 1
     or p_global_limit is null or p_global_limit < 1 then
    raise exception 'ai_reserve: neispravan ulaz' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('ai_reserve', 0));

  -- Vreme se uzima posle zaključavanja: now() je početak transakcije, pa bi
  -- zahtev koji je čekao red računao prozore i started_at iz prošlosti.
  v_now := clock_timestamp();
  v_day_start := date_trunc('day', v_now at time zone 'utc') at time zone 'utc';
  v_until_midnight :=
    ceil(extract(epoch from (v_day_start + interval '1 day' - v_now)))::int;

  delete from public.ai_calls where started_at < v_now - interval '2 days';

  -- Istovremeni: redovi u letu, ne stariji od 90 s. Oslobađa se kad najstariji
  -- među onima koji drže limit prestane da važi (najkasnije za 90 s).
  select count(*) into v_count from public.ai_calls
  where user_id = p_user_id and finished_at is null
    and started_at > v_now - interval '90 seconds';
  if v_count >= p_concurrent_limit then
    select started_at + interval '90 seconds' into v_free
    from public.ai_calls
    where user_id = p_user_id and finished_at is null
      and started_at > v_now - interval '90 seconds'
    order by started_at asc offset v_count - p_concurrent_limit limit 1;
    return jsonb_build_object(
      'limit', 'concurrent',
      'retry_after_seconds', greatest(0, ceil(extract(epoch from (v_free - v_now)))::int)
    );
  end if;

  -- Minutni: red koji drži limit izlazi iz prozora 60 s posle početka.
  select count(*) into v_count from public.ai_calls
  where user_id = p_user_id and started_at > v_now - interval '1 minute';
  if v_count >= p_minute_limit then
    select started_at + interval '1 minute' into v_free
    from public.ai_calls
    where user_id = p_user_id and started_at > v_now - interval '1 minute'
    order by started_at asc offset v_count - p_minute_limit limit 1;
    return jsonb_build_object(
      'limit', 'minute',
      'retry_after_seconds', greatest(0, ceil(extract(epoch from (v_free - v_now)))::int)
    );
  end if;

  -- Dnevni po vrsti (UTC): oslobađa se u ponoć.
  select count(*) into v_count from public.ai_calls
  where user_id = p_user_id and kind = p_kind and started_at >= v_day_start;
  if v_count >= p_daily_limit then
    return jsonb_build_object('limit', 'daily', 'retry_after_seconds', v_until_midnight);
  end if;

  -- Zajednički za sve korisnike i redove bez korisnika (obrisani nalozi).
  select count(*) into v_count from public.ai_calls where started_at >= v_day_start;
  if v_count >= p_global_limit then
    return jsonb_build_object('limit', 'global', 'retry_after_seconds', v_until_midnight);
  end if;

  insert into public.ai_calls (user_id, kind, started_at)
  values (p_user_id, p_kind, v_now)
  returning id into v_id;
  return jsonb_build_object('id', v_id);
end;
$$;

-- Zatvara red; ponovljeno ili nepoznato oslobađanje ne radi ništa.
create or replace function public.ai_release(p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.ai_calls set finished_at = now()
  where id = p_id and finished_at is null;
$$;

revoke execute on function public.ai_reserve(uuid, text, int, int, int, int)
  from public, anon, authenticated;
revoke execute on function public.ai_release(uuid) from public, anon, authenticated;
grant execute on function public.ai_reserve(uuid, text, int, int, int, int) to service_role;
grant execute on function public.ai_release(uuid) to service_role;
