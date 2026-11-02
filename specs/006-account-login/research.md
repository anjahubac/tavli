# Research: Account, sign-in and server storage (006a)

Decisions behind [plan.md](plan.md). Each entry: Decision / Rationale / Alternatives.

## R1. Supabase client package

- **Decision**: `supabase` (pure Dart, 2.16.x) — not `supabase_flutter`.
- **Rationale**: one client for Auth (GoTrue), PostgREST, Storage and Functions.
  The pure Dart package lets us own session persistence (we store the session
  JSON in Keychain/Keystore through the existing `SecretStorage`, FR-007) and
  takes an injectable `http.Client`, so the thin Supabase adapters can be tested
  with `package:http/testing` `MockClient` (no network, constitution V).
  `supabase_flutter` persists the session in SharedPreferences by default and
  pulls in `app_links`/`shared_preferences` plugins we do not need for an
  email-code flow.
- **Alternatives**: `supabase_flutter` with a custom `LocalStorage` (works, but
  more plugins and global `Supabase.instance` state that is awkward in tests);
  raw dio calls to GoTrue/PostgREST (re-implements token refresh and errors).

## R2. Email one-time code flow and error mapping

- **Decision**: `auth.signInWithOtp(email:, shouldCreateUser: true)` then
  `auth.verifyOTP(type: OtpType.email, email:, token:)`. Email is trimmed and
  lower-cased before both calls. Code input keeps digits only and auto-submits at 6.
  Server config (`supabase/config.toml`): `otp_length = 6`, `otp_expiry = 600`,
  `[auth.email] max_frequency = "30s"`; the 30 s resend countdown is also
  enforced in the client.
- **Error mapping** (`AuthFailure` sealed class → Serbian text in
  `authErrorText`):
  - GoTrue returns the same error (`otp_expired`, "Token has expired or is
    invalid") for a wrong and an expired code. The client remembers when the
    last code was sent: older than 600 s → `codeExpired` ("Kod je istekao…"),
    otherwise `wrongCode` ("Kod nije ispravan…").
  - HTTP 429 / `over_email_send_rate_limit` / `over_request_rate_limit` → `rateLimited`.
  - `SocketException`, `TimeoutException`, `ClientException` → `offline`.
  - 5xx, missing `SUPABASE_URL`/`SUPABASE_ANON_KEY`, anything else → `unavailable`.
- **Alternatives**: magic link (needs deep links per platform; rejected in spec).

## R3. Session storage, offline start and expiry

- **Decision**: `SessionStore` writes `Session.toJson()` to secure storage under
  the key `auth_session` (never `api_key_*`) on `signedIn`/`tokenRefreshed`, and
  deletes it on sign-out/deletion. On app start:
  1. no stored session → `signedOut`;
  2. stored session + cached `Accounts` row → the app opens immediately
     (`signedIn` or `needsName`) **without network**; the user id is read from the
     stored session JSON;
  3. in the background, when online, `auth.recoverSession(json)` refreshes the
     token; `autoRefreshToken` keeps it fresh while the app runs, and on resume
     the session is refreshed if it expired.
  A refresh that fails with an auth error (`refresh_token_not_found`,
  `refresh_token_already_used`, `session_not_found`, `user_not_found`, HTTP
  400/401/403 from `/token`) → `signedOut(reason: sessionExpired)`; cache and
  outbox stay (FR-008). A network error during refresh keeps the user signed in
  and is retried later (US8-4).
  If the server reports `user_not_found` (account deleted elsewhere), the
  account's local cache is removed as well (edge case in spec).
- **Rationale**: SC-002 (no re-sign-in for 30 days; refresh tokens do not expire
  by default in Supabase) and FR-009 (offline restart).
- **Alternatives**: calling `recoverSession` before showing the app (blocks
  offline start).

## R4. Record ids

- **Decision**: every synced record has a client-generated text id. New ids are
  UUID v4 from `newId()` in `lib/domain/ids.dart` (`Random.secure`, no new
  dependency). Existing text ids (recipes, shopping lists, meal plans; base36
  from `newRecipeId`) are kept. Local tables with integer autoincrement ids
  (`recipe_versions`, `pantry_items`, `shopping_items`, `meal_plan_entries`,
  `ratings`) move to text ids in drift schema v4; existing rows get
  `lower(hex(randomblob(16)))`. On the server, ids are `text primary key`
  (length 1–64). `newRecipeId` is replaced by `newId()` for new records.
- **Rationale**: idempotent upserts by id (FR-013, constitution II) and no
  re-keying of legacy data during the move (FR-019).
- **Alternatives**: `uuid` primary keys on the server (would force re-keying
  legacy base36 ids and every JSON reference); a separate `syncId` column next to
  integer ids (two identities per row, error-prone); `uuid` package (unneeded for
  one function).

## R5. Server data model and ownership

- **Decision**: tables in `public`: `profiles`, `households`,
  `household_members`; household data `recipes`, `recipe_versions`,
  `shopping_lists`, `shopping_items`, `pantry_items`, `meal_plans`,
  `meal_plan_entries` (each with `household_id`); personal data `ratings`,
  `taste_profiles` (each with `user_id`); `deletions` (tombstones). JSON lists
  become `jsonb`. Each data table has `created_at` (client value), `updated_at`
  (server, trigger `clock_timestamp()`) and `updated_by` (`auth.uid()`).
  Provisioning: `AFTER INSERT ON auth.users` trigger (`private.handle_new_user`,
  `security definer`) creates profile, household "Moje domaćinstvo" and owner
  membership in one transaction — exactly once per account (FR-010).
  Details: [data-model.md](data-model.md), [contracts/server-schema.md](contracts/server-schema.md).
- **Alternatives**: client creating the household after sign-in (race between
  devices, needs insert rights on `households`); one `jsonb` document per
  household (no per-row RLS, huge conflicts).

## R6. Row Level Security and grants

- **Decision**: RLS enabled on every `public` table; policies use
  `private.is_member(household_id)` / `user_id = (select auth.uid())`
  (`security definer`, `stable`, in the `private` schema that is not exposed
  through the API, to avoid policy recursion on `household_members`;
  `authenticated` gets only `usage` on the schema and `execute` on this one
  function, because policies run with the caller's rights). Migrations start with
  `revoke all on all tables in schema public from anon, authenticated` and grant
  per table only what the app needs (`select, insert, update, delete` on data
  tables; `select` + `update (display_name)` on `profiles`; `select` on
  `households`, `household_members`, `deletions`). `anon` gets nothing.
  `alter default privileges in schema public revoke all ... from anon, authenticated`
  plus `auto_expose_new_tables = false` (already in `config.toml`).
  Storage: private bucket `recipe-photos`, object path
  `{household_id}/{file}.jpg`; `storage.objects` policies check
  `private.is_member(((storage.foldername(name))[1])::uuid)`.
- **Tests**: pgTAP files in `supabase/tests/` run with `supabase test db`: a
  catalog check that **every** `public` table has RLS and no `anon` privilege
  (catches future tables), plus two-account tests (A, B) for select / insert /
  update / delete on every table and on storage objects (SC-006).
- **Alternatives**: RLS only on data tables (constitution forbids); policies
  with inline subqueries on `household_members` (recursion risk, slower).

## R7. Writes: outbox

- **Decision**: drift table `SyncOutbox` (per account). Repositories write the
  row and the outbox entry in one drift transaction (FR-013) via a shared
  `SyncedWriter`. Entry = `(seq, accountId, entity, recordId, op, state,
  attempts, nextAttemptAt, lastError)`; `op` ∈ `upsert | delete | photoUpload |
  photoDelete`. The payload is **read from the local row at send time** (the
  queue holds identities, not snapshots), so:
  - a second upsert of a record that already has a pending upsert is coalesced
    (the earlier `seq` is kept, so a parent always stays ahead of its children);
  - a delete removes pending upserts of that record and appends a delete;
  - a pending upsert whose row is gone is dropped.
  Uploader: takes pending entries in `seq` order, groups consecutive entries with
  the same entity+op into batches of ≤ 100 (bulk `upsert(onConflict: 'id')` /
  `delete().inFilter('id', …)`); a batch failing with a 4xx is retried row by
  row to isolate the bad row. Classification:
  - network / timeout / 5xx / 429 → transient: stop, back off 5 s → 10 s → 30 s (cap);
  - 401 → refresh session once and retry; refresh refused → session expired (R3);
  - other 4xx / Postgres `22xxx`, `23xxx`, `42501` → permanent: `state = rejected`,
    continue with the next entry (FR-014).
  Photo entries (`photoUpload`/`photoDelete`) run in a second pass after the
  data entries and never stop them: a failed photo gets `nextAttemptAt` and is
  retried with the next run, so a recipe is saved on the server without waiting
  for its photo (spec edge case "Photo upload failure").
- **Rationale**: exactly-once effect through idempotent upserts by client id
  (SC-003) and no blocking by a bad entry.
- **Alternatives**: snapshot payloads (bigger queue, stale data sent);
  per-row requests only (hundreds of requests on the first move).

## R8. Deletes and conflict rule (FR-016, FR-017)

- **Decision**: real `DELETE` on the server (the data is really gone), plus an
  `AFTER DELETE` trigger on every data table that inserts a tombstone into
  `deletions(entity, record_id, household_id | user_id, deleted_at)`. A
  `BEFORE INSERT` trigger on every data table returns `NULL` (silently skips the
  row) when the record id — or, for child tables, its parent id — has a
  tombstone, so a late edit from another device can never resurrect a deleted
  record ("deletion wins"). Updates simply overwrite ("last write to reach the
  server wins"); there is no version check in 006a. Cascades
  (`recipe_versions`, `ratings` → `on delete cascade`;
  `meal_plan_entries.recipe_id` → `on delete set null`) fire the same triggers,
  so other devices learn about them.
- **Alternatives**: soft delete with a `deleted_at` column (content stays on the
  server — contradicts "deleted on the server too"); version numbers / merge
  (009).

## R9. Reads: download with cursors

- **Decision**: per account and entity a cursor `(updatedAt, lastId)` in
  `SyncCursors`. Download pages of 500 rows ordered by `(updated_at, id)` with the
  keyset filter `updated_at > c or (updated_at = c and id > lastId)`, starting
  60 s before the stored cursor (overlap for transactions that commit late;
  upserts by id are idempotent). The cursor is saved after each page, so an
  interrupted download resumes (US4-2). Entity order: profile/household →
  recipes → recipe_versions → shopping_lists → shopping_items → pantry_items →
  meal_plans → meal_plan_entries → ratings → taste_profiles → deletions.
  Applying a page: rows with a pending or rejected outbox entry are skipped (the local change
  will be sent and then wins on the server); tombstones delete the local row and
  drop its pending entries (deletion wins). The first complete download sets
  `Accounts.initialDownloadDone`; later runs fetch only changes (US4-4).
  Triggers: after sign-in, on app start online, on resume after ≥ 15 min since
  the last pull (confirmed in Clarifications).
- **Alternatives**: one RPC returning all changes (bigger single responses, more
  SQL to test); Realtime (009).

## R10. Photos

- **Decision**: local files stay in `<documents>/recipe_photos/{file}.jpg`
  (already downscaled ≤ 1600 px JPEG). Remote object key =
  `{household_id}/{file}.jpg` in bucket `recipe-photos`; the server `image_path`
  column holds only `{file}.jpg`. A new photo enqueues `photoUpload` (recordId =
  local relative path) next to the recipe upsert; photo entries are sent after
  the data entries and do not block them (R7); upload uses `upsert: true`
  (idempotent). Another device that sees `image_path` before the object exists
  gets a 404 and retries on its next pull. A recipe delete enqueues `photoDelete` for photos no longer
  referenced by any recipe or version of the household. Downloads: after data
  pages are applied, `PhotoSync` fetches missing files referenced by recipes and
  versions (4 in parallel); failures are retried on the next pull, the UI shows
  the existing placeholder meanwhile (US4-1, edge case "photos may finish later").
- **Alternatives**: photos as base64 in Postgres (size limits, slow); public
  bucket (constitution forbids).

## R11. Per-account cache, legacy move, sign-out

- **Decision**: user-data tables get `householdId` (household data) or `userId`
  (personal data), nullable. `null` = data that predates accounts. Every query in
  repositories filters by the active `AccountScope` (userId + householdId), so
  another account on the device sees nothing of the first (FR-022). Legacy move
  (FR-019): one drift transaction sets `householdId`/`userId` on all `null` rows,
  enqueues their upserts (parents first) and photo uploads and writes
  `AppSettings['legacy_move'] = {accountId, finishedAt}`. A single SQLite
  transaction is atomic, so an interrupted move either did not happen or is
  complete (US5-3); the uploads that follow are resumable outbox entries. Taste
  profile: the legacy row is moved only if the account has none.
  Sign-out: delete the stored session, `auth.signOut(scope: SignOutScope.local)`,
  stop sync; cache, outbox and the `Accounts` row stay (FR-023).
- **Alternatives**: separate SQLite file per account (simpler isolation but
  the legacy move would copy across databases and model cooldowns/settings would
  need a third DB); deleting the cache on sign-out (contradicts the spec).

## R12. Account deletion

- **Decision**: Supabase Edge Function `delete-account`
  (`supabase/functions/delete-account/index.ts`, Deno). It verifies the caller's
  JWT, then with the platform-provided service role (env of the function only —
  never in the app or repo): (1) lists households where the caller is the only
  member and removes their Storage objects through the Storage API; (2) calls
  `public.delete_account_data(uid)` (executable by `service_role` only) (deletes those households → cascade, the
  caller's memberships, ratings, taste profile, profile, tombstones);
  (3) `auth.admin.deleteUser(uid)`. Every step is idempotent, so a retry after a
  failure finishes the job. The app calls it with `functions.invoke`; only on
  HTTP 200 does it delete the device data (rows of the account, outbox, cursors,
  `Accounts` row, photo files of the household) and the own AI keys
  (`KeyStore.clear()`), then the session.
- **Rationale**: deleting `auth.users` and Storage objects needs privileges the
  client must not have; Supabase blocks deleting `storage.objects` rows from SQL,
  so photos must go through the Storage API.
- **Alternatives**: `security definer` SQL RPC deleting `auth.users` plus client
  deleting photos first (two calls, partial deletes on failure).

## R13. Sync scheduling and status

- **Decision**: `SyncEngine` (one per signed-in account) runs push then pull.
  Push is triggered by: sign-in, app start, resume, every local write (debounced
  1 s → SC-003 10 s target) and the backoff timer (cap 30 s while there are
  waiting changes and the app is in the foreground, so a returned network is
  noticed within a minute — SC-003). No `connectivity_plus`: failures tell us we
  are offline. `SyncStatus` (stream) = `allSaved | sending | waiting(n) |
  rejected(n)`, shown in "Profil" (FR-018); progress phases `moving` /
  `downloading` drive the "Čuvam tvoje podatke…" / "Preuzimam tvoje podatke…"
  banner.
- **Alternatives**: `connectivity_plus` (another plugin; connectivity ≠ reachability).

## R14. Testing approach

- **Flutter**: interfaces `AuthGateway`, `SyncRemote`, `PhotoRemote`,
  `AccountApi`; in-memory fakes in `test/helpers/fake_backend.dart` emulate
  RLS-free server semantics (upsert by id, tombstones, delete wins, cursors,
  injected failures: offline, 5xx, permanent 4xx, interruption after N rows).
  Supabase adapters are tested against `MockClient` with recorded-shape JSON
  (fake values only). Drift: `NativeDatabase.memory()`, migration v3 → v4 test.
- **Database**: `supabase test db` (pgTAP) against the local stack; helper
  `tests.authenticate_as(uuid)` sets `role authenticated` and
  `request.jwt.claims`. Edge function: exercised in [quickstart.md](quickstart.md)
  against the local stack (`supabase start` serves `supabase/functions`).
- **Alternatives**: Flutter integration tests against the local stack in CI
  (needs Docker in CI; can be added later).

## R15. Dependencies

| Package | Where | Justification |
|---|---|---|
| `supabase` ^2.16.5 | dependencies | Auth (email OTP, refresh), PostgREST, Storage and Functions client for the decided backend; pure Dart so the session stays in our secure storage. |
| `http` ^1.6.0 | dependencies | `http.Client` type injected into `SupabaseClient` (already transitive) and `MockClient` for adapter tests. |

No `uuid`, `connectivity_plus` or `supabase_flutter`.
