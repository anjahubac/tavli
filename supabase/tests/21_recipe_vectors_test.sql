begin;
select plan(35);
select tests.create_user('vectors-a@test.local') as ua \gset
select tests.create_user('vectors-b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset
select ('[1,' || repeat('0,', 1022) || '0]')::extensions.vector as v1,
       ('[0,1,' || repeat('0,', 1021) || '0]')::extensions.vector as v2 \gset

insert into public.recipes
  (id, household_id, title, servings, source, ingredients, steps, meal_types, weight)
values
  ('vector-soup', :'ha', 'Čorba', 2, 'manual', '[{"name":"sočivo"}]', '[]', array['dinner'], 'light'),
  ('vector-bread', :'ha', 'Hleb', 2, 'manual', '[]', '[]', null, null),
  ('vector-other', :'hb', 'Sarma', 2, 'manual', '[]', '[]', null, null);

select ok(not has_function_privilege('anon',
  'public.rank_recipe_vectors(extensions.vector,text[])', 'execute'), 'anon cannot rank');
select ok(not has_function_privilege('authenticated',
  'public.claim_recipe_vectors()', 'execute'), 'client cannot claim jobs');
select ok(not has_function_privilege('authenticated',
  'public.complete_recipe_vector(text,uuid,extensions.vector)', 'execute'), 'client cannot write vectors');
select ok(not has_table_privilege('authenticated', 'private.recipe_vectors', 'update'),
  'client cannot write vectors directly');
select ok(not has_table_privilege('authenticated', 'private.recipe_vectors', 'select'),
  'client cannot read raw derived vectors');
select ok(not has_table_privilege('service_role', 'private.recipe_vectors', 'update'),
  'worker writes only through the lease RPC');

select ok(not has_function_privilege('anon',
  'public.enable_recipe_vector_indexing(uuid)', 'execute'), 'anon cannot opt in');
select ok(not has_table_privilege('authenticated', 'private.recipe_vector_consents', 'insert'),
  'client cannot insert consent directly');
set local role service_role;
select is((select count(*) from public.claim_recipe_vectors()
  where recipe_id in ('vector-soup','vector-bread','vector-other')), 0::bigint,
  'worker cannot claim any recipe before household consent');
reset role;

select ok(not has_function_privilege('anon',
  'public.can_search_recipe_vectors()', 'execute'), 'anon cannot check search consent');
select tests.authenticate_as(:'ua');
select ok(not public.can_search_recipe_vectors(),
  'search is refused before household consent');
select tests.authenticate_as(:'ua');
select ok(not public.enable_recipe_vector_indexing(:'hb'), 'cannot opt in another household');
select ok(public.enable_recipe_vector_indexing(:'ha'), 'member can opt in their household');
select ok(public.enable_recipe_vector_indexing(:'ha'), 'repeated opt-in is idempotent');
select tests.clear_auth();
select tests.authenticate_as(:'ua');
select ok(public.can_search_recipe_vectors(),
  'a member of the consenting household may search');
select ok(exists (select 1 from public.rank_recipe_vectors(:'v1', array['not-synced-yet'])) is false,
  'unsynced candidates simply rank nothing');
select tests.clear_auth();
select tests.authenticate_as(:'ub');
select ok(not public.can_search_recipe_vectors(),
  'a household without consent cannot search');
select ok(not exists (select 1 from public.rank_recipe_vectors(:'v1', array['vector-soup'])),
  'another household cannot rank consenting recipes');
select tests.clear_auth();
select is((select count(*) from private.recipe_vector_consents where household_id = :'ha'),
  1::bigint, 'opt-in is recorded once');

set local role service_role;
create temp table claimed_recipe_vectors as select * from public.claim_recipe_vectors();
select is((select count(*) from claimed_recipe_vectors where recipe_id = 'vector-other'),
  0::bigint, 'worker skips the household which has not opted in');
select * from claimed_recipe_vectors where recipe_id = 'vector-soup' \gset soup_
select ok(:'soup_content' like '%Čorba%' and :'soup_content' like '%sočivo%'
  and :'soup_content' like '%dinner%' and :'soup_content' like '%light%', 'embedding input includes title, ingredients and labels');
reset role;
update public.recipes set weight = 'hearty', labels_source = 'user'
where id = 'vector-soup';

set local role service_role;
select ok(not public.complete_recipe_vector('vector-soup', :'soup_lease', :'v1'),
  'an older in-flight embedding cannot overwrite an edit');
select * from public.claim_recipe_vectors() where recipe_id = 'vector-soup' \gset next_
select ok(:'next_content' like '%hearty%', 'the edit requeues the changed recipe');
select ok(public.complete_recipe_vector('vector-soup', :'next_lease', :'v1'),
  'the current lease saves the embedded vector');
select ok(not public.complete_recipe_vector('vector-soup', :'next_lease', :'v2'),
  'a completed lease cannot be replayed');

reset role;
update private.recipe_vectors set retry_at = now() - interval '1 second'
where recipe_id = 'vector-bread';
set local role service_role;
select * from public.claim_recipe_vectors() where recipe_id = 'vector-bread' \gset retry_
select ok(not public.complete_recipe_vector('vector-bread',
  (select lease from claimed_recipe_vectors where recipe_id = 'vector-bread'), :'v2'),
  'a retry replaces the expired lease');
select ok(public.complete_recipe_vector('vector-bread', :'retry_lease', :'v2'),
  'the retry is saved by the new lease');
reset role;

select tests.authenticate_as(:'ub');
select ok(public.enable_recipe_vector_indexing(:'hb'), 'second household can independently opt in');
select tests.clear_auth();
set local role service_role;
select * from public.claim_recipe_vectors() where recipe_id = 'vector-other' \gset other_
select ok(public.complete_recipe_vector('vector-other', :'other_lease', :'v1'),
  'the other household indexes only after its opt-in');
reset role;

select tests.authenticate_as(:'ua');
select is(
  (select array_agg(recipe_id order by distance) from public.rank_recipe_vectors(
    :'v1', array['vector-bread','vector-other','vector-soup'])),
  array['vector-soup','vector-bread'], 'ranking uses cosine distance and excludes the other household');
select is(
  (select array_agg(recipe_id) from public.rank_recipe_vectors(:'v1', array['vector-bread'])),
  array['vector-bread'], 'only eligible local candidates are ranked');

select is(
  (select count(*) from public.rank_recipe_vectors('[1,0]'::extensions.vector, array['vector-bread'])),
  0::bigint, 'wrong query vector dimensions cannot enter ranking');

select tests.authenticate_as(:'ub');
select is(
  (select array_agg(recipe_id) from public.rank_recipe_vectors(:'v1', array['vector-other','vector-soup'])),
  array['vector-other'], 'second household cannot see the first');
select tests.clear_auth();

update public.recipes set steps = '["Kuvaj."]' where id = 'vector-soup';
select ok((select embedding is not null from private.recipe_vectors where recipe_id = 'vector-soup'),
  'changing unrelated steps retains the vector');
delete from public.recipes where id = 'vector-soup';
select is((select count(*) from private.recipe_vectors where recipe_id = 'vector-soup'), 0::bigint,
  'deleting the source recipe deletes its vector');
select * from finish();
rollback;
