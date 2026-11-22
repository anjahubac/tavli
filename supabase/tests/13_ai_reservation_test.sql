-- 015 slice 2: tabela ai_calls i rezervacija limita (ugovor „Reservation“).
-- Svi limiti se proveravaju i troše u jednoj transakciji pre poziva provajdera;
-- neuspela rezervacija ne upisuje ništa; red u letu starije od 90 s ne blokira;
-- brisanje naloga čuva zajednički brojač bez korisnika; klijent nema pristup.
begin;
select * from no_plan();

select tests.create_user('ai-a@test.local') as ua \gset
select tests.create_user('ai-b@test.local') as ub \gset

-- Skraćenica: rezervacija sa dnevnim, minutnim, istovremenim i zajedničkim limitom.
create function pg_temp.reserve(uid uuid, kind text, daily int, per_minute int, concurrent int, glob int)
returns jsonb language sql as $$
  select public.ai_reserve(uid, kind, daily, per_minute, concurrent, glob)
$$;

select has_table('public', 'ai_calls', 'tabela ai_calls postoji');
select has_function('public', 'ai_reserve', array['uuid', 'text', 'integer', 'integer', 'integer', 'integer'], 'ai_reserve postoji');
select has_function('public', 'ai_release', array['uuid'], 'ai_release postoji');

-- Uspešna rezervacija vraća id i upisuje jedan red bez teksta zahteva.
select ok((pg_temp.reserve(:'ua', 'text', 5, 20, 2, 100)) ? 'id', 'prva rezervacija vraća id');
select is((select count(*) from public.ai_calls where user_id = :'ua'), 1::bigint, 'upisan je jedan red');
select is((select count(*) from public.ai_calls where user_id = :'ua' and finished_at is null and kind = 'text'), 1::bigint, 'red je u letu, vrste text');

-- Istovremeni limit (2): treća rezervacija je odbijena kao concurrent.
select ok((pg_temp.reserve(:'ua', 'text', 5, 20, 2, 100)) ? 'id', 'druga u letu prolazi');
select is(pg_temp.reserve(:'ua', 'text', 5, 20, 2, 100) ->> 'limit', 'concurrent', 'treća u letu je concurrent');
select cmp_ok((pg_temp.reserve(:'ua', 'text', 5, 20, 2, 100) ->> 'retry_after_seconds')::int, '>=', 0, 'retry_after_seconds nije negativan');
select is((select count(*) from public.ai_calls where user_id = :'ua'), 2::bigint, 'odbijena rezervacija ne upisuje ništa');

-- ai_release oslobađa red; ponovljeno oslobađanje ne menja vreme.
select public.ai_release((select id from public.ai_calls where user_id = :'ua' order by started_at, id limit 1));
select is((select count(*) from public.ai_calls where user_id = :'ua' and finished_at is null), 1::bigint, 'jedan red je oslobođen');
select lives_ok($$select public.ai_release('00000000-0000-4000-8000-0000000000ff')$$, 'oslobađanje nepoznatog id-a ne baca grešku');
-- now() ostaje isto u celoj transakciji; starije vreme čini promenu vidljivom.
update public.ai_calls
set finished_at = finished_at - interval '1 second'
where user_id = :'ua' and finished_at is not null
returning id as released_id, finished_at as first_finish \gset
select public.ai_release(:'released_id');
select is((select finished_at from public.ai_calls where id = :'released_id'), :'first_finish'::timestamptz, 'ponovljeno oslobađanje ne menja vreme završetka');
select ok(pg_temp.reserve(:'ua', 'text', 5, 20, 2, 100) ? 'id', 'posle oslobađanja ponovo prolazi');

-- Red u letu stariji od 90 s više ne blokira (ali se računa u minut i dan).
update public.ai_calls set finished_at = now() where user_id = :'ua';
update public.ai_calls set finished_at = null, started_at = now() - interval '100 seconds' where user_id = :'ua';
select ok(pg_temp.reserve(:'ua', 'text', 50, 50, 1, 100) ? 'id', 'istekao red u letu ne blokira istovremeni limit');

-- Minutni limit: svi redovi korisnika počinju pre 10 s, limit je njihov broj.
update public.ai_calls set finished_at = now(), started_at = now() - interval '10 seconds' where user_id = :'ua';
select count(*) as n_minute from public.ai_calls where user_id = :'ua' \gset
select is(pg_temp.reserve(:'ua', 'text', 50, :n_minute, 2, 100) ->> 'limit', 'minute', 'minutni limit važi');
select ok((pg_temp.reserve(:'ua', 'text', 50, :n_minute, 2, 100) ->> 'retry_after_seconds')::int between 49 and 51, 'minutni retry je oko 50 s (red izlazi iz prozora)');
select is((select count(*) from public.ai_calls where user_id = :'ua'), :'n_minute'::bigint, 'odbijen minutni zahtev ne upisuje ništa');

-- Dnevni limit je po vrsti: vision ne troši text i obrnuto.
select is(pg_temp.reserve(:'ua', 'text', 4, 50, 5, 100) ->> 'limit', 'daily', 'dnevni text limit važi');
select ok(pg_temp.reserve(:'ua', 'vision', 4, 50, 5, 100) ? 'id', 'vision ima svoj dnevni brojač');
select cmp_ok((pg_temp.reserve(:'ua', 'text', 4, 50, 5, 100) ->> 'retry_after_seconds')::int, '<=', 86400, 'dnevni retry je do ponoći UTC');

-- Zajednički limit važi za sve korisnike.
select is(pg_temp.reserve(:'ub', 'text', 50, 50, 5, 5) ->> 'limit', 'global', 'zajednički limit važi i za drugog korisnika');
select ok(pg_temp.reserve(:'ub', 'text', 50, 50, 5, 500) ? 'id', 'drugi korisnik ima sopstvene limite');

-- Neispravni ulazi se odbijaju bez upisa.
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'audio', 1, 1, 1, 1)$$, '22023', null, 'nepoznata vrsta se odbija');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 0, 1, 1, 1)$$, '22023', null, 'limit nula se odbija');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), null, 1, 1, 1, 1)$$, '22023', null, 'prazna vrsta se odbija kao neispravan ulaz');
select throws_ok($$select public.ai_reserve(null, 'text', 1, 1, 1, 1)$$, '22023', null, 'prazan korisnik se odbija');
-- Prazan limit ne sme da isključi proveru (null poređenje je null, ne istina).
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', null, 1, 1, 1)$$, '22023', null, 'prazan dnevni limit se odbija');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 1, null, 1, 1)$$, '22023', null, 'prazan minutni limit se odbija');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 1, 1, null, 1)$$, '22023', null, 'prazan istovremeni limit se odbija');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 1, 1, 1, null)$$, '22023', null, 'prazan zajednički limit se odbija');

-- Stari redovi (više od 2 dana) se brišu pri rezervaciji.
insert into public.ai_calls (user_id, kind, started_at, finished_at)
values (:'ub', 'text', now() - interval '3 days', now() - interval '3 days');
select pg_temp.reserve(:'ub', 'text', 50, 50, 5, 500);
select is((select count(*) from public.ai_calls where started_at < now() - interval '2 days'), 0::bigint, 'redovi stariji od 2 dana su obrisani');

-- Brisanje naloga: redovi ostaju bez korisnika i dalje se računaju u zajednički limit.
select count(*) as ub_rows, array_agg(id) as ub_ids from public.ai_calls where user_id = :'ub' \gset
select count(*) as before_global from public.ai_calls where started_at >= date_trunc('day', now() at time zone 'utc') at time zone 'utc' \gset
delete from auth.users where id = :'ub';
select is((select count(*) from public.ai_calls where user_id = :'ub'), 0::bigint, 'nijedan red ne pokazuje na obrisan nalog');
select is((select count(*) from public.ai_calls where user_id is null and id = any(:'ub_ids'::uuid[])), :'ub_rows'::bigint, 'redovi obrisanog naloga su sačuvani bez korisnika');
select cmp_ok(:'ub_rows'::bigint, '>=', 1::bigint, 'nalog je imao bar jedan red pre brisanja');
select is((select count(*) from public.ai_calls where started_at >= date_trunc('day', now() at time zone 'utc') at time zone 'utc'), :'before_global'::bigint, 'brisanje naloga ne smanjuje zajednički brojač');

-- Klijent nema pristup tabeli ni funkcijama.
select tests.authenticate_as(:'ua');
select throws_ok($$select count(*) from public.ai_calls$$, '42501', null, 'prijavljen korisnik ne čita ai_calls');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 1, 1, 1, 1)$$, '42501', null, 'prijavljen korisnik ne poziva ai_reserve');
select throws_ok($$select public.ai_release(gen_random_uuid())$$, '42501', null, 'prijavljen korisnik ne poziva ai_release');
select tests.authenticate_anon();
select throws_ok($$select count(*) from public.ai_calls$$, '42501', null, 'anon ne čita ai_calls');
select throws_ok($$select public.ai_reserve(gen_random_uuid(), 'text', 1, 1, 1, 1)$$, '42501', null, 'anon ne poziva ai_reserve');

-- Servisna uloga sme da poziva funkcije.
select tests.clear_auth();
select set_config('role', 'service_role', true);
select lives_ok(format($$select public.ai_reserve(%L, 'text', 50, 50, 5, 500)$$, :'ua'), 'service_role poziva ai_reserve');

select * from finish();
rollback;
