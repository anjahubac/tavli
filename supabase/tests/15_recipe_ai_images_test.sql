-- TRELLO-130: kolone AI slike na receptu, zaštita slike korisnika i limiti
-- slika (ai_image_reserve). Klijent nema pristup tabeli ni funkciji.
begin;
select * from no_plan();

select tests.create_user('img-a@test.local') as ua \gset
select tests.create_user('img-b@test.local') as ub \gset
select household_id as ha from public.household_members where user_id = :'ua' \gset

create function pg_temp.reserve(uid uuid, recipe text, per_user int, project int, attempts int)
returns jsonb language sql as $$
  select public.ai_image_reserve(uid, recipe, per_user, project, attempts)
$$;

select has_column('public', 'recipes', 'image_description', 'recipes.image_description postoji');
select has_column('public', 'recipes', 'image_source', 'recipes.image_source postoji');
select has_table('public', 'ai_image_requests', 'tabela ai_image_requests postoji');

-- Uspešna rezervacija vraća id i domaćinstvo korisnika.
select is(pg_temp.reserve(:'ua', 'r1', 2, 100, 3) ->> 'household_id', :'ha', 'vraća domaćinstvo korisnika');
select is((select count(*) from public.ai_image_requests where user_id = :'ua'), 1::bigint, 'upisan je jedan red');

-- Isti recept istog dana ne troši novi limit, ali broji pokušaje.
select ok(pg_temp.reserve(:'ua', 'r1', 2, 100, 3) ? 'id', 'isti recept ponovo prolazi');
select is((select count(*) from public.ai_image_requests where user_id = :'ua'), 1::bigint, 'ponovljen recept nema novi red');
select is((select attempts from public.ai_image_requests where user_id = :'ua'), 2, 'ponovljen recept broji pokušaj');
select ok(pg_temp.reserve(:'ua', 'r1', 2, 100, 3) ? 'id', 'treći pokušaj prolazi');
select is(pg_temp.reserve(:'ua', 'r1', 2, 100, 3) ->> 'limit', 'user', 'četvrti pokušaj istog recepta je odbijen');

-- Dnevni limit po korisniku broji različite recepte.
select ok(pg_temp.reserve(:'ua', 'r2', 2, 100, 3) ? 'id', 'drugi recept prolazi');
select is(pg_temp.reserve(:'ua', 'r3', 2, 100, 3) ->> 'limit', 'user', 'treći recept prelazi limit 2');
select cmp_ok((pg_temp.reserve(:'ua', 'r3', 2, 100, 3) ->> 'retry_after_seconds')::int, '<=', 86400, 'retry je do ponoći UTC');
select is((select count(*) from public.ai_image_requests where user_id = :'ua'), 2::bigint, 'odbijen zahtev ne upisuje ništa');

-- Zajednički limit važi za sve korisnike.
select is(pg_temp.reserve(:'ub', 'x1', 30, 2, 3) ->> 'limit', 'project', 'zajednički limit važi i za drugog korisnika');
select ok(pg_temp.reserve(:'ub', 'x1', 30, 100, 3) ? 'id', 'drugi korisnik ima svoj limit');

-- Zajednički limit broji i ponovljene pozive istog recepta (4 + 1 do sada).
select is(pg_temp.reserve(:'ub', 'x1', 30, 5, 3) ->> 'limit', 'project', 'ponovljen poziv ne zaobilazi zajednički limit');

-- Neispravni ulazi.
select throws_ok($$select public.ai_image_reserve(gen_random_uuid(), '../x', 1, 1, 1)$$, '22023', null, 'neispravan id recepta se odbija');
select throws_ok($$select public.ai_image_reserve(gen_random_uuid(), 'r', null, 1, 1)$$, '22023', null, 'prazan limit se odbija');
select is(public.ai_image_reserve(gen_random_uuid(), 'r', 1, 1, 1) ->> 'error', 'no_household', 'korisnik bez domaćinstva');

-- Stari redovi se brišu.
insert into public.ai_image_requests (user_id, recipe_id, day)
values (:'ub', 'old', (now() at time zone 'utc')::date - 5);
select pg_temp.reserve(:'ub', 'x2', 30, 100, 3);
select is((select count(*) from public.ai_image_requests where recipe_id = 'old'), 0::bigint, 'redovi stariji od 2 dana se brišu');

-- AI slika ne zamenjuje sliku korisnika (ni sa zastarelog uređaja).
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps, image_path, image_source)
values ('rp', :'ha', 'Sarma', 4, 'ai', '[]', '[]', 'moja.jpg', 'user');
update public.recipes set image_path = 'ai_x.jpg', image_source = 'ai' where id = 'rp';
select is((select image_path from public.recipes where id = 'rp'), 'moja.jpg', 'slika korisnika ostaje');
select is((select image_source from public.recipes where id = 'rp'), 'user', 'izvor slike ostaje user');
update public.recipes set image_source = null, title = 'Sarmice' where id = 'rp';
select is((select image_source from public.recipes where id = 'rp'), 'user', 'izmena bez izvora ne briše izvor');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps, image_path)
values ('rl', :'ha', 'Pita', 4, 'photo', '[]', '[]', 'stara.jpg');
update public.recipes set image_path = 'ai_z.jpg', image_source = 'ai' where id = 'rl';
select is((select image_path from public.recipes where id = 'rl'), 'stara.jpg', 'stara slika bez izvora ostaje');
insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
values ('ra', :'ha', 'Pasulj', 4, 'ai', '[]', '[]');
update public.recipes set image_path = 'ai_y.jpg', image_source = 'ai', image_description = 'Beans' where id = 'ra';
select is((select image_source from public.recipes where id = 'ra'), 'ai', 'AI slika se upisuje u recept bez slike');
update public.recipes set image_description = null where id = 'ra';
select is((select image_description from public.recipes where id = 'ra'), 'Beans', 'opis se ne briše praznom izmenom');
select throws_ok($$update public.recipes set image_source = 'robot' where id = 'ra'$$, '23514', null, 'nepoznat izvor slike se odbija');

-- Klijent nema pristup tabeli ni funkciji.
select tests.authenticate_as(:'ua');
select throws_ok($$select count(*) from public.ai_image_requests$$, '42501', null, 'prijavljen korisnik ne čita tabelu');
select throws_ok($$select public.ai_image_reserve(auth.uid(), 'r9', 30, 30, 3)$$, '42501', null, 'prijavljen korisnik ne zove funkciju');
select is((select image_source from public.recipes where id = 'ra'), 'ai', 'član domaćinstva vidi izvor slike');
select tests.authenticate_as(:'ub');
select is((select count(*) from public.recipes where id = 'ra'), 0::bigint, 'drugo domaćinstvo ne vidi recept');
reset role;

-- Brisanje naloga ostavlja samo anoniman brojač.
delete from auth.users where id = :'ua';
select is((select count(*) from public.ai_image_requests where user_id = :'ua'), 0::bigint, 'nema redova obrisanog korisnika');
select is((select count(*) from public.ai_image_requests where user_id is null and recipe_id is not null), 0::bigint, 'anoniman red nema id recepta');
select cmp_ok((select count(*) from public.ai_image_requests where user_id is null), '>=', 2::bigint, 'anoniman red ostaje u zajedničkom brojaču');

select * from finish();
rollback;
