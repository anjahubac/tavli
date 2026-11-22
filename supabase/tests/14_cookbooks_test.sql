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
insert into public.cookbooks (id, household_id, title, filename, storage_path, status, pages, created_by) values
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 'Knjiga A', 'a.pdf', :'ha' || '/a.pdf', 'ready', 2, :'ua'),
  ('c0000000-0000-4000-8000-00000000000b', :'hb', 'Knjiga B', 'b.pdf', :'hb' || '/b.pdf', 'ready', 1, :'ub');
-- Isti vektor (osa 1) u obe knjige: razlikuje ih samo vlasnik, ne sličnost.
insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 1, 0, 'Sarma: kupus i mleveno meso.', pg_temp.unit(1)),
  ('c0000000-0000-4000-8000-00000000000a', :'ha', 2, 0, 'Pita sa jabukama.', pg_temp.unit(2)),
  ('c0000000-0000-4000-8000-00000000000b', :'hb', 1, 0, 'Tajni recept domaćinstva B.', pg_temp.unit(1));

select has_table('public', 'cookbooks', 'tabela cookbooks postoji');
select has_table('public', 'cookbook_chunks', 'tabela cookbook_chunks postoji');
select has_function('public', 'cookbook_search', array['uuid', 'vector', 'integer', 'uuid'], 'cookbook_search postoji');

-- Član A vidi samo svoje knjige i chunkove.
select tests.authenticate_as(:'ua');
select is((select count(*) from public.cookbooks), 1::bigint, 'A vidi samo svoju knjigu');
select is((select title from public.cookbooks), 'Knjiga A', 'A vidi Knjigu A');
select is((select count(*) from public.cookbook_chunks), 2::bigint, 'A vidi samo svoje chunkove');

-- Klijent ne piše knjige ni chunkove: ni sopstveno domaćinstvo (obrada je server).
select throws_ok(format($$insert into public.cookbooks (household_id, title, filename, storage_path, created_by) values (%L, 'x', 'x.pdf', 'x', %L)$$, :'ha', :'ua'), '42501', null, 'klijent ne pravi knjigu direktno');
select throws_ok($$insert into public.cookbook_chunks (cookbook_id, household_id, page, chunk_index, content, embedding) values ('c0000000-0000-4000-8000-00000000000a', gen_random_uuid(), 1, 9, 'x', array_fill(0::real, array[768])::extensions.vector)$$, '42501', null, 'klijent ne piše chunkove');
select throws_ok($$select public.cookbook_search(gen_random_uuid(), array_fill(0.1::real, array[768])::extensions.vector, 5, null)$$, '42501', null, 'klijent ne zove cookbook_search');

-- Server: pretraga filtrira domaćinstva pre rangiranja.
select tests.clear_auth();
select set_config('role', 'service_role', true);
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, null)), 2::bigint, 'pretraga za A vraća samo chunkove A');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, null) where content like '%domaćinstva B%'), 0::bigint, 'tuđi chunk se ne vraća ni uz identičan vektor');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, 'c0000000-0000-4000-8000-00000000000b')), 0::bigint, 'tuđa knjiga u p_book_id ne vraća ništa');
select is((select page from public.cookbook_search(:'ua', pg_temp.unit(2), 1, null)), 2, 'najbliži chunk dolazi prvi i nosi stranicu');
select ok((select max(score) <= 1.0001 from public.cookbook_search(:'ua', pg_temp.unit(2), 10, null)), 'ocena je sličnost, ne udaljenost');
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 1, null)), 1::bigint, 'limit se poštuje');
select throws_ok($$select * from public.cookbook_search('00000000-0000-4000-8000-000000000001', pg_temp.unit(1), 0, null)$$, '22023', null, 'limit nula se odbija');
select is((select count(*) from public.cookbook_search(gen_random_uuid(), pg_temp.unit(1), 10, null)), 0::bigint, 'nepoznat korisnik ne dobija ništa');

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
select is((select count(*) from public.cookbook_search(:'ua', pg_temp.unit(1), 10, null)), 0::bigint, 'bivši član ne pretražuje');
select tests.clear_auth();

-- Brisanje knjige briše i chunkove.
delete from public.cookbooks where id = 'c0000000-0000-4000-8000-00000000000a';
select is((select count(*) from public.cookbook_chunks where cookbook_id = 'c0000000-0000-4000-8000-00000000000a'), 0::bigint, 'brisanjem knjige nestaju chunkovi');
select is((select count(*) from public.cookbook_chunks), 1::bigint, 'chunkovi drugog domaćinstva ostaju');

-- Skladište: prvi deo putanje je id domaćinstva čiji je korisnik član.
select tests.authenticate_as(:'ub');
select lives_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'hb' || '/b.pdf', :'ub'), 'član B upisuje u svoju putanju');
select throws_ok(format($$insert into storage.objects (bucket_id, name, owner) values ('cookbooks', %L, %L)$$, :'ha' || '/tudja.pdf', :'ub'), '42501', null, 'član B ne upisuje u putanju domaćinstva A');
select is((select count(*) from storage.objects where bucket_id = 'cookbooks'), 1::bigint, 'B vidi samo svoj objekat');
select tests.clear_auth();
select ok((select not public from storage.buckets where id = 'cookbooks'), 'bucket cookbooks je privatan');
select is((select file_size_limit from storage.buckets where id = 'cookbooks'), 15728640::bigint, 'limit fajla je 15 MB');

select * from finish();
rollback;
