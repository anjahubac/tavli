-- Slike: A radi sa objektima pod {A domaćinstvo}/, B i anon ne mogu ništa.
begin;
select plan(11);

select tests.create_user('a@test.local') as ua \gset
select tests.create_user('b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
-- Supabase inače brani DELETE nad storage.objects iz SQL-a; ovde testiramo politike.
set local storage.allow_delete_query = 'true';

select tests.authenticate_as(:'ua');
select lives_ok(
  format($$insert into storage.objects (bucket_id, name, owner_id) values ('recipe-photos', %L, auth.uid()::text)$$, :'ha' || '/a.jpg'),
  'A dodaje sliku u svoje domaćinstvo'
);
select is((select count(*) from storage.objects where bucket_id = 'recipe-photos'), 1::bigint, 'A vidi svoju sliku');
select is(
  tests.affected(format($$update storage.objects set metadata = '{"x":1}' where name = %L$$, :'ha' || '/a.jpg')),
  1::bigint, 'A menja svoju sliku'
);
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('recipe-photos', %L)$$, tests.household_of(:'ub') || '/x.jpg'),
  '42501', null, 'A ne dodaje sliku u tuđe domaćinstvo'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('recipe-photos', 'nije-uuid/x.jpg')$$,
  '42501', null, 'putanja bez domaćinstva se odbija'
);
select tests.clear_auth();

select tests.authenticate_as(:'ub');
select is((select count(*) from storage.objects where bucket_id = 'recipe-photos'), 0::bigint, 'B ne vidi A-ovu sliku');
select is(
  tests.affected(format($$update storage.objects set metadata = '{"x":2}' where name = %L$$, :'ha' || '/a.jpg')),
  0::bigint, 'B ne menja A-ovu sliku'
);
select is(
  tests.affected(format($$delete from storage.objects where name = %L$$, :'ha' || '/a.jpg')),
  0::bigint, 'B ne briše A-ovu sliku'
);
select throws_ok(
  format($$insert into storage.objects (bucket_id, name) values ('recipe-photos', %L)$$, :'ha' || '/b.jpg'),
  '42501', null, 'B ne dodaje sliku u A-ovo domaćinstvo'
);
select tests.clear_auth();

select tests.authenticate_anon();
select is((select count(*) from storage.objects where bucket_id = 'recipe-photos'), 0::bigint, 'anon ne vidi slike');
select tests.clear_auth();

select tests.authenticate_as(:'ua');
select is(
  tests.affected(format($$delete from storage.objects where name = %L$$, :'ha' || '/a.jpg')),
  1::bigint, 'A briše svoju sliku'
);
select tests.clear_auth();

select * from finish();
rollback;
