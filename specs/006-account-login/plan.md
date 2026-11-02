# Implementation Plan: Account, sign-in and server storage (006a)

**Branch**: `006-account-login` (from latest `main`) | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-account-login/spec.md`

## Summary

Sign-in becomes mandatory: after the (optional) intro a `go_router` redirect
shows "Prijava" (email → 6-digit code via Supabase Auth OTP), then the mandatory
name step. The server (Supabase, EU) creates profile + personal household +
owner membership in an `auth.users` trigger. All user data is stored in
Postgres tables with RLS per household / person and photos in a private Storage
bucket. The drift database stays the offline cache the UI reads: schema v4 adds
account scope columns, text ids everywhere, an outbox, download cursors and a
cached `Accounts` row. Repositories write row + outbox entry in one transaction;
a `SyncEngine` uploads the outbox in order (idempotent upserts by client id,
permanent rejections parked), downloads changes by `(updated_at, id)` cursors on
sign-in / start / resume ≥ 15 min, and syncs photos. Deletes are real deletes
with server tombstones so deletions win. Pre-account data is moved into the
first account in one atomic transaction. Sign-out keeps everything; account
deletion goes through an Edge Function with the service role kept server-side.

## Technical Context

**Language/Version**: Dart ≥ 3.13, Flutter 3.47; SQL (Postgres 17, local Supabase stack); TypeScript (Deno) for one Edge Function

**Primary Dependencies**: existing (flutter_riverpod, go_router, drift, dio, flutter_secure_storage, image) + `supabase` ^2.16.5 and `http` ^1.6.0 (new, justified below)

**Storage**: Supabase Postgres (8 migrations, RLS on every table) + Storage bucket `recipe-photos`; drift schema 3 → 4 (scope columns, text ids, `Accounts`, `SyncOutbox`, `SyncCursors`); session in Keychain/Keystore (`auth_session`)

**Testing**: flutter_test with in-memory drift and a fake backend (`test/helpers/fake_backend.dart`), `MockClient` for Supabase adapters; pgTAP via `supabase test db` against the local stack (two accounts)

**Target Platform**: Android, iOS, macOS

**Project Type**: mobile/desktop app (single Flutter project) + Supabase project folder (`supabase/`)

**Performance Goals**: online change on the server ≤ 10 s (debounce 1 s); offline backlog sent ≤ 1 min after network returns (backoff cap 30 s); 200-recipe account downloaded ≤ 2 min (pages of 500, 4 parallel photo downloads); legacy move of hundreds of rows in one transaction < 1 s

**Constraints**: offline-first (everything except sign-in, delete and AI works offline, including restart); no secrets/tokens in repo, logs or drift; no service-role key in the app; EU region; RLS + explicit grants; anon has no table access

**Scale/Scope**: 2 new screens (sign-in with email/code steps, name), Profil header + 3 dialogs; 13 server tables + 1 bucket + 1 Edge Function; 10 synced entities; ~25 new Dart files

### New dependencies

- `supabase` — Auth (email OTP, token refresh), PostgREST, Storage and Functions client for the decided Supabase backend; the pure Dart package lets the session live only in Keychain/Keystore and takes an injectable HTTP client for tests (research R1).
- `http` — `http.Client` type passed to `SupabaseClient` (already transitive) and `MockClient` for adapter tests.

## Constitution Check

*GATE: passed before Phase 0, re-checked after Phase 1 (design below).*

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ all copy from the spec's UI copy table; `authErrorText` / sync status texts tested verbatim |
| II. Offline-first, account-backed | ✅ drift is the cache; row + outbox in one transaction; client ids; download on sign-in; sign-out keeps data; RLS on every table, explicit grants, `anon` none, `auto_expose_new_tables = false`; private bucket; migrations in `supabase/migrations/`; drift v4 with migration + test |
| III. AI only via AIRouter | ✅ untouched; no AI in this feature |
| IV. Secrets never committed | ✅ URL/anon key from `secrets.json` (`SupabaseConfig`, redacted `toString`); session only in secure storage; service role only in the Edge Function environment; fakes use obviously fake values; secret grep in quickstart |
| V. Test-first | ✅ domain (initials, ids, email/code normalisation), outbox/coalescing, uploader/downloader, migration, error mapping written test-first; pgTAP with two accounts for every table + storage; backend faked in Flutter tests |
| VI. Responsive | ✅ sign-in/name screens centred max 420 px; Profil header tested at 400×800 and 1200×800 |
| VII. Small commits | ✅ commit per task group (server schema, drift v4, outbox, auth, screens, sync, move, sign-out, delete) |
| VIII. One spec branch | ✅ `006-account-login` |
| IX. Best practices & guardrails | ✅ two justified dependencies; strict lints unchanged; no hand-edited `*.g.dart`; check.sh before commits |

No violations → Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/006-account-login/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── server-schema.md
│   ├── app-interfaces.md
│   └── delete-account-function.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
supabase/
├── config.toml                         otp settings, max_frequency 30s, functions.delete-account
├── migrations/2026103012xxxx_*.sql     8 migrations (contracts/server-schema.md)
├── tests/0x_*_test.sql                 pgTAP (helpers, catalog, provisioning, isolation, storage, deletions, delete_account)
├── functions/delete-account/index.ts   Edge Function
└── templates/magic_link.html           (exists)

lib/
├── domain/ids.dart                     newId() (UUID v4)
├── domain/account.dart                 Account, initials(), normalizeEmail(), normalizeCode()
├── domain/recipe_version.dart          id → String
├── account/
│   ├── supabase_config.dart            SupabaseConfig.fromEnvironment
│   ├── supabase_client.dart            client factory (injectable http.Client)
│   ├── auth_gateway.dart               AuthGateway, AuthFailure, SupabaseAuthGateway
│   ├── session_store.dart              SessionStore (SecretStorage, key auth_session)
│   ├── account_api.dart                AccountApi, SupabaseAccountApi (fetch, delete-account)
│   ├── account_service.dart            loadOrFetch, saveName, deleteAccount + local wipe
│   └── auth_controller.dart            AuthState, AuthController, accountScopeProvider
├── sync/
│   ├── entities.dart                   entity registry + mappers
│   ├── synced_writer.dart              outbox enqueue + coalescing
│   ├── sync_remote.dart                SyncRemote, PhotoRemote, SyncError, Supabase impls
│   ├── uploader.dart                   batches, classification, backoff
│   ├── downloader.dart                 cursors, pages, tombstones
│   ├── photo_sync.dart                 missing photo download
│   ├── legacy_mover.dart               one-time move of pre-account data
│   └── sync_engine.dart                scheduling, SyncStatus, SyncPhase, lifecycle
├── data/database.dart                  schema v4 (+ database.g.dart regenerated)
├── data/recipe_repository.dart         scope filter + SyncedWriter
├── features/account/
│   ├── sign_in_screen.dart             email + code steps, resend countdown
│   ├── name_screen.dart                "Kako da te zovemo?"
│   ├── auth_error_text.dart
│   ├── account_header.dart             avatar, name, email, household, role, save state
│   ├── account_dialogs.dart            edit name, sign out, delete account
│   └── sync_banner.dart                "Čuvam/Preuzimam tvoje podatke…"
├── features/settings/profile_screen.dart  header + actions above "AI ključevi"
├── ai/key_store.dart                   + KeyStore.clear()
├── app/router.dart                     redirect, /sign-in, /sign-in/name
├── app/app.dart                        lifecycle → SyncEngine
└── providers.dart                      client, gateway, session store, engine providers

test/
├── domain/account_test.dart, ids_test.dart
├── data/migration_test.dart (v3→v4), recipe_repository_test.dart (scope + outbox)
├── account/auth_gateway_test.dart (MockClient), auth_controller_test.dart, account_service_test.dart
├── sync/synced_writer_test.dart, uploader_test.dart, downloader_test.dart, photo_sync_test.dart,
│   legacy_mover_test.dart, sync_engine_test.dart, entities_test.dart, sync_remote_test.dart
├── features/account/sign_in_screen_test.dart, name_screen_test.dart, profile_account_test.dart
└── helpers/fake_backend.dart, test_app.dart (signed-in by default)
```

**Structure Decision**: single Flutter project; new `lib/account/` (auth +
account services) and `lib/sync/` (offline cache sync) layers sit between
features and Supabase, mirroring `lib/ai/`. Server code lives in `supabase/`.

## Key design points

1. **Auth** (R2, R3): pure-Dart `SupabaseClient` built only when
   `SupabaseConfig.isConfigured`; otherwise the gateway throws `Unavailable`.
   Wrong vs expired code is decided by the client from the send time.
   Offline start uses the cached `Accounts` row + stored session JSON.
2. **Ownership** (R5, R6): trigger-provisioned household; `private.is_member`
   for every policy; catalog pgTAP test guards future tables.
3. **Outbox** (R7): identities, not snapshots; coalesced; parent-first ordering
   kept by earliest `seq`; batches of 100 with row-by-row fallback.
4. **Deletes and conflicts** (R8): real deletes + tombstones; `skip_if_deleted`
   makes deletion win; plain upserts make the last write win.
5. **Download** (R9, R10): keyset cursors with 60 s overlap; skip rows with
   pending local changes; photos after data, lazily retried.
6. **Scope and move** (R11): nullable `householdId`/`userId`; every repository
   query scoped; legacy move in one transaction.
7. **Delete account** (R12): Edge Function with service role; device wipe only
   after HTTP 200.
8. **Existing code**: `RecipeRepository` gets `SyncedWriter` + `AccountScope`;
   `RecipeVersion.id` becomes `String`; `newRecipeId` replaced by `newId`;
   `test_app.dart` signs in a fake account by default so existing widget tests
   keep working.

## Owner actions (not code)

- Hosted Supabase project in the EU region; enable email OTP, apply
  `supabase/templates/magic_link.html`, custom SMTP before release.
- `supabase db push` and `supabase functions deploy delete-account` to the
  hosted project.
- Put the hosted URL and anon key in the local `secrets.json`.

## Complexity Tracking

No constitution violations.
