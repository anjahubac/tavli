# Tasks: Account, sign-in and server storage (006a)

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)
**Tests**: required (constitution V) — write each test task before its implementation task and see it fail. Flutter tests never hit the network (fake backend, `MockClient`); server rules are tested with pgTAP (`supabase test db`) against the local stack.

Format: `[ID] [P?] [Story] Description` — `[P]` = can run in parallel (different files, no unfinished dependency).

## Phase 1: Setup

- [x] T001 Add `supabase` ^2.16.5 and `http` ^1.6.0 (justified in plan.md) to `pubspec.yaml`; `flutter pub get`
- [x] T002 [P] In `supabase/config.toml`: `[auth.email] max_frequency = "30s"` (keep `otp_length = 6`, `otp_expiry = 600`), add `[functions.delete-account] verify_jwt = true`; local-only `[auth.rate_limit] email_sent = 30` so manual testing is not blocked (hosted limits are set in the dashboard); confirm `auto_expose_new_tables = false`
- [x] T003 [P] Test: `SupabaseConfig.fromEnvironment` with empty values → `isConfigured == false`; `toString` never contains the key, in `test/account/supabase_config_test.dart`
- [x] T004 Implement `lib/account/supabase_config.dart` (`SUPABASE_URL`, `SUPABASE_ANON_KEY` via `String.fromEnvironment`)

## Phase 2: Foundational (blocks all stories)

### Server schema and access rules

- [x] T005 pgTAP helpers `tests.create_user(email)`, `tests.authenticate_as(uuid)`, `tests.clear_auth()` in `supabase/tests/00_helpers.sql`
- [x] T006 [P] Test: every `public` table has RLS; `anon` has no privilege on any `public` table; `authenticated` privileges equal the grants table in contracts/server-schema.md; no `public` function executable by `anon`, `authenticated` executes only `private.is_member`; bucket `recipe-photos` is private, in `supabase/tests/01_catalog_test.sql`
- [x] T007 [P] Test: a new auth user gets exactly 1 profile (`display_name` null, lower-case email), 1 household "Moje domaćinstvo", 1 owner membership; empty and 41-char names rejected, in `supabase/tests/02_provisioning_test.sql`
- [x] T008 [P] Test: users A and B — for each of `profiles`, `households`, `household_members`, the 7 household tables, `ratings`, `taste_profiles`, `deletions`: B cannot select/insert/update/delete A's rows; A can do every granted operation on its own; A cannot move a row to B's household or rate a recipe of B's household; A cannot update its own `email`, in `supabase/tests/03_isolation_test.sql`
- [x] T009 [P] Test: A can insert/select/update/delete objects under `{A household}/` in `recipe-photos`; B and anon cannot read, write or delete them, in `supabase/tests/04_storage_test.sql`
- [x] T010 [P] Test: delete inserts a tombstone visible only to members/owner; re-insert of a deleted id and insert of a child of a deleted parent are skipped silently; cascades (recipe → versions, ratings; recipe → `meal_plan_entries.recipe_id` null) create tombstones / bump `updated_at`; `updated_at` increases on update; two updates of one row → the later one is stored (FR-017), in `supabase/tests/05_deletions_test.sql`
- [x] T011 Migration `supabase/migrations/20261030120000_private_helpers.sql` (schema `private` + `usage` for `authenticated`, `touch_updated_at`, default table privileges and function `execute` revoked)
- [x] T012 Migration `supabase/migrations/20261030120100_accounts.sql` (`profiles`, `households`, `household_members`, `private.is_member` with `execute` for `authenticated`, `private.handle_new_user` + trigger)
- [x] T013 Migration `supabase/migrations/20261030120200_household_data.sql` (7 tables per data-model.md, FKs, `(household_id, updated_at, id)` indexes)
- [x] T014 Migration `supabase/migrations/20261030120300_personal_data.sql` (`ratings`, `taste_profiles`)
- [x] T015 Migration `supabase/migrations/20261030120400_deletions.sql` (`deletions`, `record_deletion`, `skip_if_deleted` triggers on all data tables)
- [x] T016 Migration `supabase/migrations/20261030120500_rls_and_grants.sql` (RLS + policies + grants per contracts/server-schema.md)
- [x] T017 Migration `supabase/migrations/20261030120600_storage.sql` (bucket `recipe-photos` private, 5 MB, `image/jpeg`; 4 policies)
- [x] T018 `supabase start`, `supabase db reset`, `supabase test db` → T006–T010 green

### Domain and local cache

- [x] T019 [P] Test: `newId()` is UUID v4 and unique over 10 000 calls; `initials` ("Ana Petrović" → "AP", "Ana" → "A", "Đorđe Šćepanović" → "ĐŠ", extra spaces); `normalizeEmail` (" Ana@Mail.com " → "ana@mail.com", validity); `normalizeCode` ("123 456" → "123456", non-digits dropped, max 6); `normalizeName` (trim, empty → null, 40-char limit), in `test/domain/ids_test.dart` and `test/domain/account_test.dart`
- [x] T020 [P] Implement `lib/domain/ids.dart` and `lib/domain/account.dart` (`Account`, `initials`, `normalizeEmail`, `isValidEmail`, `normalizeCode`, `normalizeName`)
- [x] T021 Test: migration v3 → v4 keeps every row of every table, converts integer ids to unique text ids, keeps recipe↔version/list↔item/plan↔entry links, leaves scope columns null, creates `Accounts`, `SyncOutbox`, `SyncCursors`, in `test/data/migration_test.dart`
- [x] T022 Schema v4 in `lib/data/database.dart` (scope columns, text ids, `UserProfiles.id` text, new tables, `TableMigration` steps, outbox index); `dart run build_runner build --delete-conflicting-outputs`; `RecipeVersion.id` → `String` in `lib/domain/recipe_version.dart`; replace `newRecipeId` with `newId` in `lib/domain/recipe.dart` and callers
- [x] T023 [P] Test: `toRemote`/`fromRemote` round trip for all 10 entities (snake_case, JSON text ↔ list/map, `imagePath` `recipe_photos/x.jpg` ↔ `x.jpg`, UTC dates, scope column filled), in `test/sync/entities_test.dart`
- [x] T024 [P] Implement entity registry and mappers in `lib/sync/entities.dart`
- [x] T025 Test: `SyncedWriter` — upsert enqueues once and coalesces (earliest `seq` kept); delete drops pending upserts and appends delete; photo ops enqueued; entries carry `accountId`; a failing transaction leaves neither row nor entry, in `test/sync/synced_writer_test.dart`
- [x] T026 Implement `lib/sync/synced_writer.dart` and `AccountScope` in `lib/account/auth_controller.dart` (scope type + provider only)
- [x] T027 Test: `RecipeRepository` reads only the active household's rows; create/update (+ version, prune to 30 → version deletes)/undoLast/restore/delete (versions, ratings, meal entries → upserts, `photoDelete` for unreferenced photos, `photoUpload` for new photos) each write the expected outbox entries in the same transaction, in `test/data/recipe_repository_test.dart`
- [x] T028 Update `lib/data/recipe_repository.dart` (scope + `SyncedWriter`) and `lib/features/recipes/recipe_providers.dart` (scope from `accountScopeProvider`); recipe screens use `String` version ids

### Backend boundary and app shell

- [x] T029 [P] Interfaces `SyncRemote`, `PhotoRemote`, `SyncError` in `lib/sync/sync_remote.dart`; `AuthGateway`, `AuthSession`, `AuthFailure` in `lib/account/auth_gateway.dart`; `AccountApi`, `RemoteAccount` in `lib/account/account_api.dart` (interfaces only)
- [x] T030 [P] In-memory `FakeBackend` (auth codes, accounts + provisioning, upsert by id, tombstones + delete wins, cursors ordering, photo objects, injectable offline / 5xx / permanent 4xx / interrupt-after-N failures) in `test/helpers/fake_backend.dart`
- [x] T031 [P] Test: `SessionStore` write/read/clear under key `auth_session` with a fake `SecretStorage`; never touches `api_key_*`, in `test/account/session_store_test.dart`; implement `lib/account/session_store.dart`
- [x] T032 `AuthController` skeleton (`AuthState` sealed, `start()` from stored session + cached `Accounts`), router `redirect` + `refreshListenable`, routes `/sign-in` and `/sign-in/name` (placeholder screens), in `lib/account/auth_controller.dart` and `lib/app/router.dart`; `test/helpers/test_app.dart` signs in a fake account by default; all existing tests green

## Phase 3: User Story 1 — sign in with an email code (P1) 🎯 MVP

**Goal**: email → code → signed in; restart stays signed in, also offline.
**Independent test**: fresh install → email → code → name → "Recepti"; restart offline → app opens directly.

- [x] T033 [P] [US1] Test (`MockClient`): `SupabaseAuthGateway.sendCode` posts normalized email with `create_user: true`; `verifyCode` returns session; `otp_expired` → `WrongCode` when sent < 600 s ago, `CodeExpired` otherwise; 429 / rate-limit codes → `RateLimited`; socket/timeout → `Offline`; 5xx or unconfigured → `Unavailable`; no key or token in any exception text, in `test/account/auth_gateway_test.dart`
- [x] T034 [US1] Implement `lib/account/supabase_client.dart` (factory with injectable `http.Client`, `autoRefreshToken`) and `SupabaseAuthGateway` in `lib/account/auth_gateway.dart`; providers in `lib/providers.dart`
- [x] T035 [P] [US1] Test: `AuthController` — no session → `SignedOut`; stored session + cached account → `SignedIn` with no network call; `sendCode` → `CodeSent` (not persisted); `verify` stores the session and goes to `NeedsName`/`SignedIn`; `changeEmail` → `SignedOut`; failures keep state and expose the failure, in `test/account/auth_controller_test.dart`
- [x] T036 [US1] Implement sign-in flow in `lib/account/auth_controller.dart`
- [x] T037 [P] [US1] Widget tests: "Prijava" shown after start and no tab reachable; "Pošalji kod" disabled for invalid email and "Unesi ispravnu adresu e-pošte." after blur; code step "Poslali smo kod na {email}."; 6 digits (also pasted "123 456") verify automatically; wrong code message + field cleared; expired, rate-limit, offline, unavailable messages; "Pošalji ponovo za {s} s" counts down and enables at 30 s; "Promeni e-poštu"; deep link `/plan` while signed out lands on `/plan` after sign-in; layout at 400×800 and 1200×800, in `test/features/account/sign_in_screen_test.dart`
- [x] T038 [US1] Implement `lib/features/account/sign_in_screen.dart` and `lib/features/account/auth_error_text.dart`; wire `/sign-in` route

## Phase 4: User Story 2 — personal household and mandatory name (P1)

**Goal**: first sign-in → household + owner; name required; Profil shows account.
**Independent test**: new email → name "Ana Petrović" → Profil shows "AP", email, "Moje domaćinstvo", "Vlasnik".

- [ ] T039 [P] [US2] Test (`MockClient`): `SupabaseAccountApi.fetch` reads own profile + membership + household (retry up to 3× with 500 ms when the trigger row is not visible yet); `AccountService.loadOrFetch` writes/updates the `Accounts` row; `saveName` trims, rejects empty/>40, updates `Accounts` and enqueues `profile` upsert; existing account with a name → no name step, in `test/account/account_service_test.dart`
- [ ] T040 [US2] Implement `SupabaseAccountApi.fetch` in `lib/account/account_api.dart`, `lib/account/account_service.dart`; `profile` entity sends `update(display_name)` via `SyncRemote.updateProfileName`
- [ ] T041 [P] [US2] Widget tests: name step "Kako da te zovemo?" / "Ime" / "Nastavi" disabled for empty or spaces, 40-char limit, no back/skip; app closed on the name step → name step again; Profil header shows avatar initials, name, email, "Moje domaćinstvo", "Vlasnik"; "Izmeni ime" → "Sačuvaj" updates header everywhere; name step and Profil header at 400×800 and 1200×800, in `test/features/account/name_screen_test.dart` and `test/features/account/profile_account_test.dart`
- [ ] T042 [US2] Implement `lib/features/account/name_screen.dart`, `lib/features/account/account_header.dart`, edit-name dialog in `lib/features/account/account_dialogs.dart`; header above "AI ključevi" in `lib/features/settings/profile_screen.dart`

## Phase 5: User Story 3 — all data saved to the account, also offline (P1)

**Goal**: every change reaches the server in order, once; offline changes wait; status in Profil.
**Independent test**: offline edits → "Čeka slanje: n" → online → "Sve je sačuvano u nalogu." and rows + photo on the server.

- [ ] T043 [P] [US3] Test (`MockClient`): `SupabaseSyncRemote.upsert` sends bulk body with `on_conflict=id`; `delete` uses `id=in.(…)`; `fetchSince` builds the keyset filter and order; error classification (socket/timeout/5xx/429 → transient, 401 → unauthorized, 400/403/409/422 and PG `22xxx`/`23xxx`/`42501` → permanent with code only); `SupabasePhotoRemote.upload` uses `{household}/{file}` with upsert, in `test/sync/sync_remote_test.dart`
- [ ] T044 [US3] Implement Supabase adapters in `lib/sync/sync_remote.dart`
- [ ] T045 [P] [US3] Test (`FakeBackend`): uploader sends in `seq` order, batches ≤ 100 of same entity+op; failing batch retried row by row; permanent rejection → `rejected`, later entries still sent; transient → stop with backoff 5/10/30 s; 401 → one session refresh then retry; upsert whose row is gone is dropped; photo entries run after data entries and a failing photo upload does not stop or delay the recipe upsert (retried next run); interruption after N rows then rerun → no duplicates on the server, in `test/sync/uploader_test.dart`
- [ ] T046 [US3] Implement `lib/sync/uploader.dart`
- [ ] T047 [P] [US3] Test: `SyncEngine` push on start/resume/sign-in; local write → push within 1 s debounce (fake clock); status `AllSaved → Sending → AllSaved`, offline → `Waiting(n)`, rejected → `Rejected(n)` with priority; retry timer capped at 30 s while waiting; `stop()` cancels timers, in `test/sync/sync_engine_test.dart`
- [ ] T048 [US3] Implement `lib/sync/sync_engine.dart` (push part, status stream), providers in `lib/providers.dart`, lifecycle hook (`AppLifecycleListener`) in `lib/app/app.dart`; `SyncedWriter` kicks the engine after commit
- [ ] T049 [US3] Widget test + implementation: Profil save state texts "Sve je sačuvano u nalogu.", "Čuvam izmene…", "Čeka slanje: {n}", "Neke izmene nisu sačuvane u nalogu." in `test/features/account/profile_account_test.dart` and `lib/features/account/account_header.dart`

## Phase 6: User Story 4 — download on sign-in on any device (P1)

**Goal**: the account's data appears on a new device; later starts fetch only changes.
**Independent test**: 3 recipes (1 photo) + 2 items on device A → device B shows exactly those.

- [ ] T050 [P] [US4] Test (`FakeBackend`): full download of all 10 entities parent-first; pages of 500 with cursor saved per page; interruption mid-download then rerun → complete, no duplicates; 60 s overlap re-applies idempotently; rows with pending or rejected local outbox entries are not overwritten (FR-014: kept on the device); tombstones delete local rows and drop their pending entries; second run fetches only newer rows; `initialDownloadDone` set; rows land with the account's scope, in `test/sync/downloader_test.dart`
- [ ] T051 [US4] Implement `lib/sync/downloader.dart`
- [ ] T052 [P] [US4] Test: `PhotoSync.fetchMissing` downloads files referenced by recipes and versions that are missing locally (≤ 4 at a time), skips present ones, leaves failures for the next run, in `test/sync/photo_sync_test.dart`; implement `lib/sync/photo_sync.dart`
- [ ] T053 [US4] Test + implementation: engine pull after sign-in (full when `initialDownloadDone` is false), on start online, on resume only when `lastPullAt` ≥ 15 min ago; push before pull; phase `downloading` exposed, in `test/sync/sync_engine_test.dart` and `lib/sync/sync_engine.dart`
- [ ] T054 [US4] Widget test + implementation: banner "Preuzimam tvoje podatke…" while downloading, recipes usable before photos finish, in `test/features/account/sync_banner_test.dart`, `lib/features/account/sync_banner.dart`, `lib/app/home_shell.dart`

## Phase 7: User Story 5 — existing local data moves into the account once (P1)

**Goal**: pre-account data belongs to the first account, uploaded once, never duplicated.
**Independent test**: v3 DB with 3 recipes + 2 items → sign in → 3 + 2 on device and server; sign out/in 3× → still 3 + 2.

- [ ] T055 [P] [US5] Test: `LegacyMover` assigns all scope-null rows to the account's household/user, enqueues upserts parent-first plus photo uploads, records `legacy_move`; second call and a different account later move nothing; taste profile moved only if the account has none; an exception inside the transaction leaves everything unchanged and a rerun completes; no local data → returns 0, in `test/sync/legacy_mover_test.dart`
- [ ] T056 [US5] Implement `lib/sync/legacy_mover.dart`; engine runs it before the first download; phase `moving` → banner "Čuvam tvoje podatke…"; SnackBar "Tvoji recepti i liste su sačuvani u nalogu." when moved > 0 and its entries are sent
- [ ] T057 [US5] End-to-end test with `FakeBackend`: v3 database (3 recipes with versions and a photo, 2 shopping items) → migrate → sign in → server and device have exactly 3 + 2; account already has 2 server recipes → 5 after move (nothing overwritten); 3 sign-out/sign-in cycles → counts unchanged (SC-005), in `test/sync/legacy_move_flow_test.dart`

## Phase 8: User Story 6 — sign out keeps the data (P2)

**Goal**: sign-out removes only the session; other accounts see nothing of it.
**Independent test**: A adds recipe, signs out; B sees nothing; A back → recipe at once.

- [ ] T058 [P] [US6] Test: dialog "Odjaviti se? Tvoji podaci ostaju sačuvani u nalogu." with "Odustani"/"Odjavi se"; waiting changes add "Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo prijaviš na ovom uređaju."; "Odustani" changes nothing; confirm → session cleared, engine stopped, "Prijava" shown, cache/outbox/own AI keys/theme/cooldowns kept; account B sees none of A's recipes, name or photos; A again → recipe visible with no download and its waiting change is sent (SC-007), in `test/features/account/sign_out_test.dart`
- [ ] T059 [US6] Implement `signOut` in `lib/account/auth_controller.dart` (local sign-out, session clear, engine stop) and the dialog in `lib/features/account/account_dialogs.dart`

## Phase 9: User Story 7 — delete account in the app (P2)

**Goal**: everything of the account is deleted on the server and the device.
**Independent test**: account with recipe + photo → delete → nothing left on server/device, same email → new empty account.

- [ ] T060 [P] [US7] Test: `public.delete_account_data(A)` as `service_role` removes A's solo household with all data, memberships, ratings, taste profile, tombstones and profile; B untouched; second call no-op; `anon`/`authenticated` cannot execute it, in `supabase/tests/06_delete_account_test.sql`
- [ ] T061 [US7] Migration `supabase/migrations/20261030120700_delete_account.sql`; `supabase test db` green
- [ ] T062 [US7] Edge Function `supabase/functions/delete-account/index.ts` per contracts/delete-account-function.md (JWT check, remove photos via Storage API, RPC, `auth.admin.deleteUser`; idempotent; no logging of tokens/emails)
- [ ] T063 [P] [US7] Test: `AccountService.deleteAccount` — 200 → deletes the account's rows, outbox, cursors, `Accounts` row, its photo files and own AI keys (`KeyStore.clear`), keeps theme, model cooldowns and another account's cache; offline → `DeleteFailure.offline`, nothing deleted; 5xx → `DeleteFailure.server`, nothing deleted, in `test/account/account_service_test.dart`; `KeyStore.clear` test in `test/ai/key_store_test.dart`
- [ ] T064 [US7] Implement `SupabaseAccountApi.deleteAccount` (`functions.invoke('delete-account')`), local wipe in `lib/account/account_service.dart`, `KeyStore.clear()` in `lib/ai/key_store.dart`, `deleteAccount` in `lib/account/auth_controller.dart`
- [ ] T065 [US7] Widget test + implementation: "Obriši nalog" → dialog "Obrisati nalog?" with the spec text, red "Obriši nalog" and "Odustani"; success → "Prijava" with "Nalog je obrisan."; offline/server failure messages keep the person signed in, in `test/features/account/delete_account_test.dart` and `lib/features/account/account_dialogs.dart`

## Phase 10: User Story 8 — session stays valid and is protected (P2)

**Goal**: silent renewal; revoked session → back to sign-in without data loss.
**Independent test**: expired access token renewed silently; revoked refresh → "Sesija je istekla. Prijavi se ponovo.".

- [ ] T066 [P] [US8] Test: refreshed session is re-stored silently; refresh refused (`refresh_token_not_found` etc.) → `SignedOut(sessionExpired)`, message on "Prijava", cache + outbox kept; `user_not_found` → the account's cache removed as well; network error during refresh → stays signed in, retried on resume; signing in again with the same email shows the cache and sends the outbox, in `test/account/session_expiry_test.dart`
- [ ] T067 [US8] Implement session change handling in `lib/account/auth_controller.dart` and `lib/sync/sync_engine.dart` (unauthorized after refresh → controller), message on `lib/features/account/sign_in_screen.dart`

## Phase 11: Polish & cross-cutting

- [ ] T068 [P] Update `docs/architecture.md` (drop "planned", final module names), `docs/roadmap.md`, `AGENTS.md` structure (`lib/account/`, `lib/sync/`, `supabase/migrations`, `supabase/tests`, `supabase/functions`), `README.md` local backend steps
- [ ] T069 Run [quickstart.md](quickstart.md): `supabase db reset && supabase test db`, secret grep, `scripts/check.sh`, `flutter build macos --debug`, manual table on the local stack at phone and wide widths; time a 200-recipe account download on a second device (SC-004 ≤ 2 min) and an offline backlog flush (SC-003 ≤ 1 min); spec status → Implemented

## Dependencies

- Setup: T001 → T004, T034, T044. T002 independent.
- Server: T005 → T006–T010 (tests) → T011 → T012 → T013 → T014 → T015 → T016 → T017 → T018. T060 → T061 (after T018) → T062.
- Local: T019 → T020. T021 → T022 → T023 → T024 → T025 → T026 → T027 → T028. T029, T030, T031 after T022. T032 after T026, T031.
- Stories: Phase 2 complete → US1 (T033–T038) → US2 (T039–T042) → US3 (T043–T049) → US4 (T050–T054) → US5 (T055–T057). US6 (T058–T059) needs US1 + US3; US7 (T060–T065) needs US2 + US3; US8 (T066–T067) needs US1 + US3. US6, US7, US8 can run in parallel after US3.
- Polish after all stories.

## Parallel examples

- Phase 2: T006, T007, T008, T009, T010 (separate pgTAP files) together; T019/T020 and T023/T024 alongside the server work.
- US1: T033 and T035 and T037 (tests in separate files) together, then T034 → T036 → T038.
- US3: T043, T045, T047 together.
- After US3: US6, US7 and US8 by different people/agents (distinct files except `auth_controller.dart`: merge T059, T064, T067 sequentially).

## Implementation strategy

1. **MVP** = Phases 1–4 (server schema + RLS, drift v4, sign-in, household, name). The app is usable with an account; data is scoped but not yet uploaded — do not release at this point.
2. **Releasable 006a** = + US3, US4, US5 (all data saved, downloaded, legacy move) — the minimum that satisfies constitution II.
3. Then US6, US7 (store requirement), US8, polish. Commit after each task group with `scripts/check.sh` green.

## Analysis (/speckit-analyze, 2026-10-30)

| FR | Tasks |
|---|---|
| FR-001/002 sign-in gate | T032, T037, T038 |
| FR-003 email code only | T033–T038 |
| FR-004 6 digits, auto-check | T019, T037 |
| FR-005 resend after 30 s | T002, T037 |
| FR-006 Serbian failure messages | T033, T037 |
| FR-007 session only in secure storage | T031, T034 |
| FR-008 renewal / expired session | T066, T067 |
| FR-009 offline use and restart | T035, T047 |
| FR-010 profile + household + owner once | T007, T012, T039 |
| FR-011 mandatory name, initials | T019, T041, T042 |
| FR-012 all data on the server | T013, T014, T023, T024 |
| FR-013 row + outbox, ordered, exactly once | T025–T028, T045 |
| FR-014 rejected changes don't block | T045, T049, T050 |
| FR-015 download, incremental, resumable | T050, T053 |
| FR-016 deletions propagate | T010, T015, T025, T050 |
| FR-017 last write wins, delete wins | T010, T015, T045, T050 |
| FR-018 save state in Profil | T047, T049 |
| FR-019 one-time legacy move | T055–T057 |
| FR-020 EU region, RLS, explicit grants, private bucket | T006–T018 (EU region: owner action in plan.md) |
| FR-021 no keys in repo/logs | T003, T004, T069 |
| FR-022 per-account cache | T027, T058 |
| FR-023 sign-out keeps data | T058, T059 |
| FR-024 delete account | T060–T065 |
| FR-025 AI keys kept / deleted | T058, T063 |
| FR-026 Profil header + actions | T041, T042, T049, T059, T065 |
| FR-027 phone + wide, Serbian copy | T037, T041, T069 |

Success criteria: SC-003 (T045, T069), SC-004 (T069), SC-005 (T057), SC-006
(T006–T010, T060), SC-007 (T058), SC-008 (T060–T065), SC-009 (T069); SC-001/002
are checked manually in T069 and by T035 (no re-sign-in on restart).

Findings and fixes (no CRITICAL):

- **HIGH (fixed)** — policies run with the caller's rights, so a helper in a
  schema without `usage` would make every RLS check fail; and an RPC in the
  non-exposed `private` schema cannot be called from the Edge Function.
  Contract now grants `authenticated` `usage on schema private` + `execute` on
  `private.is_member` only, moves `delete_account_data` to `public` with
  `execute` for `service_role` only, and the catalog test checks function
  privileges (T006, T011, T012, T060, contracts/server-schema.md, R6, R12).
- **HIGH (fixed)** — plan sent photos before their recipe in one ordered queue,
  so a failing photo upload would block the recipe, contradicting the spec edge
  case "Photo upload failure". Photo entries now run after data entries and never
  block them (R7, R10, T027, T045, T055).
- **MEDIUM (fixed)** — FR-017 "last write wins" had no test (T010 extended).
- **MEDIUM (fixed)** — download could overwrite a locally kept rejected change
  (FR-014); downloader now skips pending and rejected records (R9, T050).
- **MEDIUM (fixed)** — FR-027 widths for the name step and Profil header (T041);
  SC-003/SC-004 timing checks added to T069.
- **LOW (fixed)** — server table count (13); local email rate limit raised for
  manual testing only (T002).
- **LOW (open)** — FR-020 EU region and custom SMTP are owner actions on the
  hosted project, not verifiable by tasks.
- Constitution: no conflicts (two justified dependencies; drift v4 with
  migration + test; RLS + explicit grants + pgTAP with two accounts; backend
  faked in Flutter tests). Terminology: "waiting change" (spec) = outbox entry
  (plan), defined in the spec's Key Entities.
