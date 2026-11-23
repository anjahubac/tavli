begin;
select * from no_plan();
select ok((select pubupdate and not (pubinsert or pubdelete or pubtruncate)
  from pg_catalog.pg_publication where pubname = 'supabase_realtime'),
  'only updates are published; deleting a revision cannot expose its scope');

select tests.create_user('realtime-owner@test.local') as a \gset
select tests.create_user('realtime-member@test.local') as b \gset
select tests.create_user('realtime-other@test.local') as c \gset
select tests.household_of(:'a') as home, tests.household_of(:'b') as other_home \gset
select revision as ar from public.account_sync_signals where id = :'a' \gset
select revision as br from public.account_sync_signals where id = :'b' \gset

select tests.authenticate_as(:'a');
select is(public.household_realtime_eligible(:'home'), false, 'solo household is ineligible');
select public.household_invite_token() as invite \gset
select throws_ok('update public.account_sync_signals set revision = 12',
  '42501', null, 'account cannot send its own signal');
select throws_ok('update public.household_sync_signals set revision = 12',
  '42501', null, 'member cannot send a household signal');
select tests.clear_auth();

select tests.authenticate_as(:'b');
select is(public.confirm_household_join(:'invite', :'other_home', 'leave_recipes', true,
  gen_random_uuid())->>'status', 'joined', 'member joins using the public RPC');
select is(public.household_realtime_eligible(:'home'), true, 'two members are eligible');
select is((select count(*) from public.household_sync_signals where id = :'home'), 1::bigint,
  'member can read their household signal');
select is((select count(*) from public.account_sync_signals), 1::bigint, 'only own account signal is visible');
select ok((select revision > :'br'::bigint from public.account_sync_signals where id = :'b'),
  'joining member gets personal signal');
select tests.clear_auth();

select tests.authenticate_as(:'a');
select ok((select revision > :'ar'::bigint from public.account_sync_signals where id = :'a'),
  'existing member gets personal signal on crossing threshold');
select revision as ar from public.account_sync_signals where id = :'a' \gset
select tests.clear_auth();

select tests.authenticate_as(:'c');
select is(public.household_realtime_eligible(:'home'), null::boolean, 'outsider cannot read eligibility');
select is((select count(*) from public.household_sync_signals where id = :'home'), 0::bigint,
  'outsider cannot read household signal');
select is((select count(*) from public.account_sync_signals where id in (:'a', :'b')), 0::bigint,
  'outsider cannot read other account signals');
select tests.clear_auth();

set local role anon;
select throws_ok('select * from public.account_sync_signals', '42501', null, 'anon cannot read account signals');
select throws_ok('select * from public.household_sync_signals', '42501', null, 'anon cannot read household signals');
reset role;

insert into public.shopping_lists (id, household_id, name) values ('rt-list', :'home', 'Shopping');
insert into public.shopping_items (id, household_id, list_id, name, category)
  values ('rt-milk', :'home', 'rt-list', 'Milk', 'other'),
         ('rt-bread', :'home', 'rt-list', 'Bread', 'other');

select tests.authenticate_as(:'a');
select revision as rev from public.household_sync_signals where id = :'home' \gset
update public.shopping_items set is_bought = true where list_id = 'rt-list';
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 1, 'a batch emits one revision');
savepoint discarded_edit;
update public.shopping_items set is_bought = false where id = 'rt-bread';
rollback to savepoint discarded_edit;
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 1, 'rollback leaves no signal');
delete from public.shopping_items where id = 'rt-milk';
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 2, 'delete advances revision');
insert into public.pantry_items (id, household_id, name, category, added_at)
  values ('rt-pantry', :'home', 'Salt', 'other', now());
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 3, 'pantry writes advance revision');
insert into public.meal_plans (id, household_id, start_date, end_date, meal_types)
  values ('rt-plan', :'home', '2026-11-23', '2026-11-29', '["lunch"]');
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 4, 'plan writes advance revision');

select tests.clear_auth();
select revision as br from public.account_sync_signals where id = :'b' \gset
select tests.authenticate_as(:'a');
select is(public.remove_household_member(:'b')->>'status', 'removed', 'owner removes through public RPC');
select ok((select revision > :'ar'::bigint from public.account_sync_signals where id = :'a'),
  'remaining member gets personal signal on crossing threshold');
select is(public.household_realtime_eligible(:'home'), false, 'remaining member is back to solo');
select tests.clear_auth();
select tests.authenticate_as(:'b');
select ok((select revision > :'br'::bigint from public.account_sync_signals where id = :'b'),
  'removed member can still read own newer signal');
select is((select count(*) from public.household_sync_signals where id = :'home'), 0::bigint,
  'removed member loses signal access');
select tests.clear_auth();

select * from finish();
rollback;
