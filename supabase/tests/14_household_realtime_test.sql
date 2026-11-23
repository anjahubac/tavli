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
select is(public.household_realtime_eligible(:'home'), true, 'a solo member can subscribe on multiple devices');
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

insert into public.recipes (id, household_id, title, servings, source, ingredients, steps)
  values ('rt-recipe', :'home', 'Soup', 2, 'manual', '[]', '[]');
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 5, 'recipe writes advance revision');
update public.recipes set title = 'Better soup' where id = 'rt-recipe';
select is((select revision from public.household_sync_signals where id = :'home'),
  :'rev'::bigint + 6, 'recipe edits advance revision');
select revision as ar_rename from public.account_sync_signals where id = :'a' \gset
select tests.clear_auth();
update public.households set name = 'Renamed' where id = :'home';
select tests.authenticate_as(:'a');
select is((select revision from public.account_sync_signals where id = :'a'),
  :'ar_rename'::bigint + 1, 'a rename sends each member a personal signal');
select tests.clear_auth();
update public.households set name = 'Renamed' where id = :'home';
select tests.authenticate_as(:'a');
select is((select revision from public.account_sync_signals where id = :'a'),
  :'ar_rename'::bigint + 1, 'an unchanged name sends no signal');

-- A personal change wakes other devices of the same account only.
select revision as before_favorite from public.account_sync_signals where id = :'a' \gset
select tests.clear_auth();
select revision as other_revision from public.account_sync_signals where id = :'b' \gset
select tests.authenticate_as(:'a');
insert into public.user_favorites(id, user_id, recipe_id, recipe_household_id, is_favorite)
values (:'a' || ':rt-recipe', :'a', 'rt-recipe', :'home', true);
update public.user_favorites set is_favorite = false where recipe_id = 'rt-recipe';
select tests.clear_auth();
delete from public.user_favorites where recipe_id = 'rt-recipe';
select is((select revision from public.account_sync_signals where id = :'a'),
  :'before_favorite'::bigint + 3, 'favorite insert, update and delete wake the owner');
select tests.clear_auth();
select is((select revision from public.account_sync_signals where id = :'b'),
  :'other_revision'::bigint, 'private edits do not wake another member');

-- Guard against drift: a new household-scoped table must publish signals or
-- be listed here with the reason it does not. Inspect as the test owner so
-- tables without authenticated grants are visible too.
select tests.clear_auth();
select is((
  select coalesce(string_agg(c.table_name || '.' || op.name, ', ' order by c.table_name, op.name), '')
  from information_schema.columns c
  join information_schema.tables t using (table_schema, table_name)
  -- pg_trigger.tgtype for AFTER STATEMENT INSERT, UPDATE and DELETE.
  cross join (values ('insert', 4), ('update', 16), ('delete', 8)) op(name, kind)
  where c.table_schema = 'public' and t.table_type = 'BASE TABLE'
    and c.column_name = 'household_id'
    and c.table_name not in (
      'household_members', -- personal signals, see signal_membership_change
      'deletions'          -- written by the delete triggers of the tables above
    )
    and not exists (
      select 1 from pg_catalog.pg_trigger g
      where g.tgrelid = format('public.%I', c.table_name)::regclass
        and g.tgfoid = 'private.signal_household_changes()'::regprocedure
        and g.tgtype = op.kind and g.tgenabled in ('O', 'A')
        and not g.tgisinternal
    )
), '', 'every household-scoped table publishes realtime signals');

select tests.clear_auth();
select revision as br from public.account_sync_signals where id = :'b' \gset
select tests.authenticate_as(:'a');
select is(public.remove_household_member(:'b')->>'status', 'removed', 'owner removes through public RPC');
select ok((select revision > :'ar'::bigint from public.account_sync_signals where id = :'a'),
  'remaining member gets personal signal on crossing threshold');
select is(public.household_realtime_eligible(:'home'), true, 'remaining solo member stays subscribed');
select tests.clear_auth();
select tests.authenticate_as(:'b');
select ok((select revision > :'br'::bigint from public.account_sync_signals where id = :'b'),
  'removed member can still read own newer signal');
select is((select count(*) from public.household_sync_signals where id = :'home'), 0::bigint,
  'removed member loses signal access');
select tests.clear_auth();

select * from finish();
rollback;
