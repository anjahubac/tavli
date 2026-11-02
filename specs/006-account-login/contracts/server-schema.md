# Contract: server schema, access rules and functions

Implemented as migrations in `supabase/migrations/` (timestamps illustrative)
and verified by pgTAP tests in `supabase/tests/` (`supabase test db`).
Tables and columns: [../data-model.md](../data-model.md).

## Migrations

| File | Content |
|---|---|
| `20261030120000_private_helpers.sql` | schema `private` (not in `[api] schemas`, so never reachable through the API); `grant usage on schema private to authenticated`; `private.touch_updated_at()`; `alter default privileges in schema public revoke all on tables from anon, authenticated` and `revoke execute on functions from public` |
| `20261030120100_accounts.sql` | `profiles`, `households`, `household_members`; `private.is_member(uuid)`; `private.handle_new_user()` + trigger on `auth.users` |
| `20261030120200_household_data.sql` | 7 household tables, FKs, indexes `(household_id, updated_at, id)` |
| `20261030120300_personal_data.sql` | `ratings`, `taste_profiles`, index `(user_id, updated_at, id)` |
| `20261030120400_deletions.sql` | `deletions`; `private.record_deletion()` (AFTER DELETE), `private.skip_if_deleted()` (BEFORE INSERT) on every data table |
| `20261030120500_rls_and_grants.sql` | `enable row level security` + policies on every table; grants (below) |
| `20261030120600_storage.sql` | bucket `recipe-photos` (private, 5 MB, `image/jpeg`); 4 policies on `storage.objects` |
| `20261030120700_delete_account.sql` | `public.delete_account_data(uid uuid)` (`security definer`); `revoke execute from public, anon, authenticated`; `grant execute to service_role` only |

## Grants (complete list for `authenticated`; `anon`: none)

| Table | Privileges |
|---|---|
| `profiles` | `select`; `update (display_name)` |
| `households`, `household_members`, `deletions` | `select` |
| `recipes`, `recipe_versions`, `shopping_lists`, `shopping_items`, `pantry_items`, `meal_plans`, `meal_plan_entries`, `ratings`, `taste_profiles` | `select, insert, update, delete` |

Policies are evaluated with the caller's rights, so `authenticated` gets
`usage on schema private` and `execute` on `private.is_member(uuid)` only; the
function is `security definer`, `stable`, `set search_path = ''`. All other
`private` functions (trigger functions) have `execute` revoked from `public`.
`private` is not an exposed API schema, so nothing in it can be called as RPC.
In `public`, no function is executable by `anon`, and `authenticated` cannot
execute `delete_account_data`.

## Policies

- `profiles`: `using (id = (select auth.uid()))` for select and update.
- `households`: select `using (private.is_member(id))`.
- `household_members`: select `using (private.is_member(household_id))`.
- household data tables: one policy per command, `using/with check
  (private.is_member(household_id))`.
- `ratings`: `using (user_id = (select auth.uid()))`; insert/update `with check
  (user_id = (select auth.uid()) and private.is_member((select household_id from
  public.recipes r where r.id = recipe_id)))`.
- `taste_profiles`: `user_id = (select auth.uid())`.
- `deletions`: select `using (user_id = (select auth.uid()) or
  private.is_member(household_id))`.
- `storage.objects` (bucket `recipe-photos`): select/insert/update/delete
  `private.is_member(((storage.foldername(name))[1])::uuid)`.

## Triggers

| Trigger | Tables | Behaviour |
|---|---|---|
| `on_auth_user_created` | `auth.users` after insert | profile + household + owner membership |
| `touch_updated_at` | all tables with `updated_at`, before insert/update | `updated_at = clock_timestamp()`, `updated_by = auth.uid()` where present |
| `record_deletion` | all data tables, after delete | insert into `deletions` (on conflict do nothing) with the row's `household_id` or `user_id` |
| `skip_if_deleted` | all data tables, before insert | `return null` if the row's id or its parent id is in `deletions` |

## `public.delete_account_data(uid uuid)`

Deletes, in one transaction: households where `uid` is the only member (cascade
removes their data and memberships), remaining memberships of `uid`, `ratings`
and `taste_profiles` of `uid`, `deletions` rows of those households / `uid`, the
`profiles` row. Idempotent (second call is a no-op). Executable by
`service_role` only.

## pgTAP test files (`supabase/tests/`)

| File | Proves |
|---|---|
| `00_helpers.sql` | `tests.create_user(email) → uuid`, `tests.authenticate_as(uuid)`, `tests.clear_auth()` |
| `01_catalog_test.sql` | every `public` table has RLS enabled; `anon` has no table privilege in `public`; `authenticated` privileges equal the grants table above; no `public` function executable by `anon`; `authenticated` can execute only `private.is_member` among non-builtin functions; bucket is private |
| `02_provisioning_test.sql` | new auth user → exactly 1 profile, 1 household "Moje domaćinstvo", 1 owner membership; `display_name` null; name check (empty, 41 chars rejected) |
| `03_isolation_test.sql` | users A and B: for every table, B cannot select / insert / update / delete A's rows (0 rows or `42501`), A can do all allowed operations on its own; cannot move a row to B's household; cannot update own `email` |
| `04_storage_test.sql` | A can insert/select/delete objects under its household folder; B gets nothing / is rejected; anon rejected |
| `05_deletions_test.sql` | delete creates a tombstone visible to members only; re-insert of a deleted id (and of a child of a deleted parent) is skipped; cascade creates tombstones for children; update after delete changes nothing; two sessions of the same account updating one row → the later write is stored (last write wins) |
| `06_delete_account_test.sql` | `public.delete_account_data(A)` (as `service_role`) removes all of A's rows and tombstones, leaves B untouched; second call no-op; not executable by `anon`/`authenticated` |
