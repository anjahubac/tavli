-- 026 / Task 1: privatne kuvarske knjige i izolovan retrieval.
-- Član domaćinstva vidi samo knjige svog domaćinstva; pretraga filtrira
-- domaćinstva pre rangiranja; brisanje knjige briše i chunkove; ko napusti
-- domaćinstvo odmah gubi pristup; skladište prati prvi deo putanje.
begin;
select * from no_plan();

select tests.create_user('cb-a@test.local') as ua \gset
select tests.create_user('cb-b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset

-- Jedinični vektor sa 1 na mestu k: različite ose daju različite smerove (kosinus).
create function pg_temp.unit(k int) returns extensions.vector language sql as $$
  select array_agg(case when i = k then 1.0 else 0.0 end order by i)::real[]::extensions.vector from generate_series(1, 768) i
$$;
grant execute on function pg_temp.unit(int) to public;

-- Knjige i chunkovi se prave kao service_role (obrada na serveru).
insert into public.cookbooks (id, household_id, title, filename, storage_path, content_sha256, status, pages, created_by) values
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 'Knjiga A', 'a.pdf', :'ha' || '/a.pdf', repeat('a', 64), 'ready', 2, :'ua'),
  ('c0000000-0000-4000-8000-00000000000b', :'hb', 'Knjiga B', 'b.pdf', :'hb' || '/b.pdf', repeat('b', 64), 'ready', 1, :'ub');
-- Isti vektor (osa 1) u obe knjige: razlikuje ih samo vlasnik, ne sličnost.
insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 1, 0, 'Sarma: kupus i mleveno meso.', pg_temp.unit(1)),
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 2, 0, 'Pita sa jabukama.', pg_temp.unit(2)),
  ('c0000000-0000-4000-8000-00000000000b', :'hb', 1, 0, 'Tajni recept domaćinstva B.', pg_temp.unit(1));

select has_table('public', 'cookbooks', 'tabela cookbooks postoji');
select has_table('public', 'cookbook_chunks', 'tabela cookbook_chunks postoji');
select has_function('public', 'cookbook_search', array['uuid', 'vector', 'integer', 'text', 'uuid'], 'cookbook_search postoji');

-- Član A vidi samo svoje knjige i chunkove.
select tests.authenticate_as(:'ua');
select is((select count(*) from public.cookbooks), 1::bigint, 'A vidi samo svoju knjigu');
select is((select title from public.cookbooks), 'Knjiga A', 'A vidi Knjigu A');
select is((select count(*) from public.cookbook_chunks), 2::bigint, 'A vidi samo svoje chunkove');

-- Klijent ne piše knjige ni chunkove: ni sopstveno domaćinstvo (obrada je server).
select throws_ok(format($$insert into public.cookbooks (household_id, title, filename, storage_path, created_by) values (%L, 'x', 'x.pdf', 'x', %L)$$, :'ha', :'ua'), '42501', null, 'klijent ne pravi knjigu direktno');
select throws_ok($$insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values ('c0000000-0000-4000-8000-00000000000a', gen_random_uuid(), 1, 9, 'x', array_fill(0::real, array[768])::extensions.vector)$$, '42501', null, 'klijent ne piše chunkove');
select throws_ok($$select public.cookbook_search(gen_random_uuid(), array_fill(0.1::real, array[768])::extensions.vector, 5, 'gemini-embedding-001', null)$$, '42501', null, 'klijent ne zove cookbook_search');

-- Server: pretraga filtrira domaćinstva pre rangiranja.
select tests.clear_auth();
select set_config('role', 'service_role', true);
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'gemini-embedding-001', null)), 2::bigint, 'pretraga za A vraća samo chunkove A');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'another-model', null)), 0::bigint, 'vektori drugog modela se ne pretražuju');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'gemini-embedding-001', null) where content like '%domaćinstva B%'), 0::bigint, 'tuđi chunk se ne vraća ni uz identičan vektor');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'gemini-embedding-001', 'c0000000-0000-4000-8000-00000000000b')), 0::bigint, 'tuđa knjiga u p_book_id ne vraća ništa');
select is((select page from public.cookbook_search(:'ua', pg_temp.unit(2), 1, 'gemini-embedding-001', null)), 2, 'najbliži chunk dolazi prvi i nosi stranicu');
select ok((select max(score) <= 1.0001 from public.cookbook_search(:'ua', pg_temp.unit(2), 10, 'gemini-embedding-001', null)), 'ocena je sličnost, ne udaljenost');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 1, 'gemini-embedding-001', null)), 1::bigint, 'limit se poštuje');
select throws_ok($$select * from public.cookbook_search('00000000-0000-4000-8000-000000000001', pg_temp.unit(1), 0, 'gemini-embedding-001', null)$$, '22023', null, 'limit nula se odbija');
select is((select count(*) from public.cookbook_search(gen_random_uuid(), pg_temp.unit(1), 10, 'gemini-embedding-001', null)), 0::bigint, 'nepoznat korisnik ne dobija ništa');

-- Idempotentno upisivanje: isti (knjiga, stranica, indeks) ne može dvaput.
select tests.clear_auth();
select throws_ok($$insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values ('c0000000-0000-4000-8000-00000000000a', (select household_id from public.cookbooks where id = 'c0000000-0000-4000-8000-00000000000a'), 1, 0, 'duplikat', pg_temp.unit(3))$$, '23505', null, 'duplikat chunka se odbija');
-- Chunk mora da pripada domaćinstvu svoje knjige.
select throws_ok($$insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values ('c0000000-0000-4000-8000-00000000000a', gen_random_uuid(), 3, 0, 'tuđe domaćinstvo', pg_temp.unit(3))$$, '23503', null, 'chunk sa pogrešnim domaćinstvom se odbija');
-- Nedozvoljen status.
select throws_ok(format($$insert into public.cookbooks (household_id, title, filename, storage_path, status) values (%L, 't', 'f.pdf', 'p', 'nesto')$$, :'ha'), '23514', null, 'nepoznat status se odbija');

-- Ko napusti domaćinstvo, odmah gubi pristup (RLS i pretraga).
delete from public.household_members where user_id = :'ua' and household_id = :'ha';
select tests.authenticate_as(:'ua');
select is((select count(*) from public.cookbooks), 0::bigint, 'bivši član ne vidi knjige');
select tests.clear_auth();
select set_config('role', 'service_role', true);
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'gemini-embedding-001', null)), 0::bigint, 'bivši član ne pretražuje');
select tests.clear_auth();

-- Brisanje knjige briše i chunkove.
delete from public.cookbooks where id = 'c0000000-0000-4000-8000-00000000000a';
select is((select count(*) from public.cookbook_chunks where cookbook_id = 'c0000000-0000-4000-8000-00000000000a'), 0::bigint, 'brisanjem knjige nestaju chunkovi');
select is((select count(*) from public.cookbook_chunks), 1::bigint, 'chunkovi drugog domaćinstva ostaju');


-- Granica od 20 knjiga po domaćinstvu važi u bazi (trka dva zahteva ne sme da je prođe).
select tests.clear_auth();
insert into public.cookbooks (household_id, title, filename, storage_path, content_sha256)
select :'hb', 'Knjiga ' || i, 'k' || i || '.pdf', :'hb' || '/k' || i || '.pdf', md5(i::text) || md5((i + 100)::text) from generate_series(1, 19) i;
select is((select count(*) from public.cookbooks where household_id = :'hb'), 20::bigint, 'B ima 20 knjiga (jedna od ranije i 19 novih)');
select throws_ok(format($$insert into public.cookbooks (household_id, title, filename, storage_path, content_sha256) values (%L, 'dvadeset prva', 'x.pdf', %L, repeat('x',64))$$, :'hb', :'hb' || '/x.pdf'), '23514', 'cookbook_limit', '21. knjiga domaćinstva se odbija u bazi');
select lives_ok(format($$insert into public.cookbooks (household_id, title, filename, storage_path, content_sha256) values (%L, 'drugo domaćinstvo', 'y.pdf', %L, repeat('y',64))$$, :'ha', :'ha' || '/y.pdf'), 'limit je po domaćinstvu');

-- Atomsko preuzimanje obrade: samo jedan poziv dobija knjigu.
insert into public.cookbooks (id, household_id, title, filename, storage_path, content_sha256) values
  ('c0000000-0000-4000-8000-0000000000c1', :'ha', 'Za obradu', 'o.pdf', :'ha' || '/o.pdf', repeat('c', 64));
select set_config('role', 'service_role', true);
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001'), true, 'prvo preuzimanje uspeva');
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001'), false, 'drugo preuzimanje dok je prvo u toku ne uspeva');
select tests.clear_auth();
update public.cookbooks set claimed_at = now() - interval '400 seconds' where id = 'c0000000-0000-4000-8000-0000000000c1';
select set_config('role', 'service_role', true);
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001'), true, 'zastarelo preuzimanje (srušen poziv, preko 300 s) se može preuzeti');
select public.release_cookbook('c0000000-0000-4000-8000-0000000000c1');
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001'), true, 'posle oslobađanja ponovo uspeva');
select tests.clear_auth();
update public.cookbooks set status = 'ready' where id = 'c0000000-0000-4000-8000-0000000000c1';
select set_config('role', 'service_role', true);
select public.release_cookbook('c0000000-0000-4000-8000-0000000000c1');
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001'), false, 'gotova knjiga se ne preuzima');
insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding)
select id, household_id, 1, 0, 'stari model', pg_temp.unit(1)
from public.cookbooks where id = 'c0000000-0000-4000-8000-0000000000c1';
update public.cookbooks set next_page = 5, pages = 4 where id = 'c0000000-0000-4000-8000-0000000000c1';
select is(public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'new-embedding-model'), true, 'promena modela preuzima gotovu knjigu za re-embed');
select is((select count(*) from public.cookbook_chunks where cookbook_id = 'c0000000-0000-4000-8000-0000000000c1'), 0::bigint, 'promena modela briše neuporedive vektore');
select is((select next_page from public.cookbooks where id = 'c0000000-0000-4000-8000-0000000000c1'), 1, 'promena modela vraća obradu na prvu stranu');
select is((select embedding_model from public.cookbooks where id = 'c0000000-0000-4000-8000-0000000000c1'), 'new-embedding-model', 'model se čuva po knjizi');
select public.release_cookbook('c0000000-0000-4000-8000-0000000000c1');
select is(public.claim_cookbook('00000000-0000-4000-8000-0000000000ee', 'gemini-embedding-001'), false, 'nepoznata knjiga se ne preuzima');
select tests.clear_auth();
select tests.authenticate_as(:'ub');
select throws_ok($$select public.claim_cookbook('c0000000-0000-4000-8000-0000000000c1', 'gemini-embedding-001')$$, '42501', null, 'klijent ne preuzima obradu');
select throws_ok($$select public.release_cookbook('c0000000-0000-4000-8000-0000000000c1')$$, '42501', null, 'klijent ne oslobađa obradu');
select tests.clear_auth();

-- Skladište: prihvata samo fajl direktno u folderu domaćinstva i ne dozvoljava
-- zamenu fajla koji već ima registrovanu knjigu.
select tests.authenticate_as(:'ub');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'hb' || '/b.pdf', :'ub'), 'član B upisuje u svoju putanju');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'ha' || '/tudja.pdf', :'ub'), '42501', null, 'član B ne upisuje u putanju domaćinstva A');
select is((select count(*) from storage.objects where bucket_id = 'cookbooks'), 1::bigint, 'B vidi samo svoj objekat');
select is(tests.affected(format($$update storage.objects set name = name where bucket_id = 'cookbooks' and name = %L$$, :'hb' || '/b.pdf')), 0::bigint, 'registrovani fajl ne može da se zameni');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'hb' || '/cekanje.pdf', :'ub'), 'neobradivi upload može da se nastavi');
select is(tests.affected(format($$update storage.objects set name = name where bucket_id = 'cookbooks' and name = %L$$, :'hb' || '/cekanje.pdf')), 1::bigint, 'neupisani fajl može da se otpremi ponovo');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'hb' || '/nested/knjiga.pdf', :'ub'), '42501', null, 'ne prihvata ugnježdenu putanju');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'hb' || '/slika.png', :'ub'), '42501', null, 'ne prihvata nepodržan nastavak');
select throws_ok(format($$update storage.objects set name = %L where bucket_id = 'cookbooks' and name = %L$$, :'ha' || '/preuzeto.pdf', :'hb' || '/cekanje.pdf'), '42501', null, 'objekat se ne premešta u tuđe domaćinstvo');
select tests.clear_auth();
select ok((select not public from storage.buckets where id = 'cookbooks'), 'bucket cookbooks je privatan');
select is((select file_size_limit from storage.buckets where id = 'cookbooks'), 15728640::bigint, 'limit fajla je 15 MB');

select * from finish();
rollback;
