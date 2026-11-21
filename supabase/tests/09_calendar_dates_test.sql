-- 016 / D1-002: kalendarski dani plana i nedeljne liste su `date`, ne
-- trenutak. Nova aplikacija šalje `YYYY-MM-DD`; stara šalje ponoć UTC kao
-- vremensku oznaku i dobija isti dan. Provere perioda i jedinstvenost liste
-- po nedelji važe i dalje; trenuci (`created_at`) ostaju `timestamptz`.
begin;
select * from no_plan();

select tests.create_user('a@test.local') as ua \gset
select tests.household_of(:'ua') as ha \gset

select col_type_is('public', 'meal_plans', 'start_date', 'date', 'početak plana je datum');
select col_type_is('public', 'meal_plans', 'end_date', 'date', 'kraj plana je datum');
select col_type_is('public', 'meal_plan_entries', 'date', 'date', 'dan obroka je datum');
select col_type_is('public', 'shopping_lists', 'period_start', 'date', 'početak nedelje liste je datum');
select col_type_is('public', 'shopping_lists', 'period_end', 'date', 'kraj nedelje liste je datum');
select col_type_is('public', 'meal_plans', 'created_at', 'timestamp with time zone', 'trenutak nastanka ostaje vremenska oznaka');

select tests.authenticate_as(:'ua');

-- Nova aplikacija: datum bez vremena.
select lives_ok(format($$insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('p_new', %L, '2026-12-28', '2027-01-03', '["lunch"]')$$, :'ha'),
  'datum bez vremena se prima');
select is((select start_date from public.meal_plans where id = 'p_new'), '2026-12-28'::date, 'početak je isti dan');
select is((select end_date from public.meal_plans where id = 'p_new'), '2027-01-03'::date, 'kraj je isti dan');

-- Stara aplikacija: ponoć UTC kao vremenska oznaka daje isti dan.
select lives_ok(format($$insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('p_old', %L, '2026-12-31T00:00:00.000Z', '2027-01-06T00:00:00.000Z', '["lunch"]')$$, :'ha'),
  'vremenska oznaka starog klijenta se prima');
select is((select start_date from public.meal_plans where id = 'p_old'), '2026-12-31'::date, 'stari zapis početka je isti dan');
select is((select end_date from public.meal_plans where id = 'p_old'), '2027-01-06'::date, 'stari zapis kraja je isti dan');

select lives_ok(format($$insert into public.meal_plan_entries (id, household_id, plan_id, date, meal_type) values ('e_old', %L, 'p_old', '2027-01-01T00:00:00.000Z', 'lunch'), ('e_new', %L, 'p_old', '2027-01-02', 'lunch')$$, :'ha', :'ha'),
  'dan obroka u oba zapisa se prima');
select is((select date from public.meal_plan_entries where id = 'e_old'), '2027-01-01'::date, 'stari zapis obroka je isti dan');
select is((select date from public.meal_plan_entries where id = 'e_new'), '2027-01-02'::date, 'novi zapis obroka je isti dan');

select lives_ok(format($$insert into public.shopping_lists (id, household_id, name, meal_plan_id, week, period_start, period_end) values ('l_old', %L, 'Nedelja 1', 'p_old', 1, '2026-12-28T00:00:00.000Z', '2027-01-03T00:00:00.000Z')$$, :'ha'),
  'nedelja starog klijenta se prima');
select is((select period_start from public.shopping_lists where id = 'l_old'), '2026-12-28'::date, 'stari početak nedelje je isti dan');
select is((select period_end from public.shopping_lists where id = 'l_old'), '2027-01-03'::date, 'stari kraj nedelje je isti dan');

-- Ograničenja perioda važe i posle promene tipa.
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, meal_plan_id, week, period_start, period_end) values ('l_dup', %L, 'Nedelja 1', 'p_old', 1, '2026-12-28', '2027-01-03')$$, :'ha'),
  '23505', null, 'plan i dalje ima jednu listu po nedelji (stari i novi zapis istog dana)');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, period_start, period_end) values ('l_rev', %L, 'x', '2027-01-03', '2026-12-28')$$, :'ha'),
  '23514', null, 'kraj nedelje ne može pre početka');
select throws_ok(format($$insert into public.shopping_lists (id, household_id, name, period_start) values ('l_half', %L, 'x', '2026-12-28')$$, :'ha'),
  '23514', null, 'nedelja ima i početak i kraj');
select throws_ok(format($$insert into public.meal_plans (id, household_id, start_date, end_date, meal_types) values ('p_bad', %L, '2026-02-30', '2026-03-01', '["lunch"]')$$, :'ha'),
  '22008', null, 'nepostojeći datum se odbija');

select * from finish();
rollback;
