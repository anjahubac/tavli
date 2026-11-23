begin;
select plan(5);
select tests.create_user('recipe-rag-a@test.local') as ua \gset
select tests.create_user('recipe-rag-b@test.local') as ub \gset
select tests.household_of(:'ua') as ha \gset
select tests.household_of(:'ub') as hb \gset

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values
  ('own-soup', :'ha', 'Čorba od sočiva', 2, 'manual', '[{"name":"sočivo"}]', '["Kuvaj na tihoj vatri."]'),
  ('own-bread', :'ha', 'Hleb', 2, 'manual', '[]', '[]'),
  ('other-soup', :'hb', 'Čorba sa sočivom', 2, 'manual', '[]', '[]');

select ok(not has_function_privilege('anon',
  'public.saved_recipe_question_candidates(text)', 'execute'), 'anon nema RPC');
select tests.authenticate_as(:'ua');
select is(
  (select id from public.saved_recipe_question_candidates('Kako se kuva corba od sociva?') limit 1),
  'own-soup', 'naziv i sastojci se nalaze i bez kvačica');
select is(
  (select count(*) from public.saved_recipe_question_candidates('sočivo')),
  2::bigint, 'A vidi samo svoje recepte');
select ok(
  (select content like '%Kuvaj na tihoj vatri%' from public.saved_recipe_question_candidates('sočivo') where id = 'own-soup'),
  'priprema ulazi u kontekst');
select tests.authenticate_as(:'ub');
select results_eq(
  $$select id from public.saved_recipe_question_candidates('sočivo')$$,
  $$values ('other-soup'::text)$$, 'B ne vidi recepte A');
select * from finish();
rollback;
