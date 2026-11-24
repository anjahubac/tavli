# Implementation Plan: Installable web app (PWA) for iOS and macOS

**Spec**: [spec.md](spec.md) | **Date**: 2026-11-24 | **Baseline**: `origin/main` `5b37b9a` (tree = `origin/dev` `5634500`)
**Branch / PR base**: `036-pwa-web` / dev
**Owner / reviewer**: Anja (Dev 4) / Matija (Dev 3), proposed | **Status**: Draft

## Summary

Add a Flutter **web** target next to the existing native targets and serve it as an
installable PWA, so people can open and install Tavli on iPhone/iPad and Mac
without signed bundles. **This is strictly additive** (owner instruction 2026-11-24):

- `ios/` and `macos/` and their settings (Xcode projects, entitlements, Info.plist,
  Podfiles, signing config) are **not modified**.
- Native behaviour on iOS, macOS, Android, Windows and Linux stays identical. Every
  code change is a new web-only branch selected at compile time (conditional import
  or `kIsWeb`). The native code path keeps the exact existing implementation.
- Nothing is removed or replaced. Native builds remain the developer path.

Smallest deliverable (slice 1): the app compiles for the web, is hosted on Cloudflare
for production (D3), installs on iPhone and Mac, signs in with the email code and shows
synced data. AI, photos, voice and hardening follow in later slices.

## Technical Context

Flutter 3.50.0, Riverpod, go_router, drift 2.35 + drift_flutter 0.3, Supabase Dart
client 2.16, dio 5, flutter_secure_storage 11 (all from `pubspec.yaml`/lock).
Web-relevant findings on the baseline (details in [research.md](research.md)):

- `lib/data/database.dart:586` uses `driftDatabase(name: 'tavli')`. drift_flutter
  supports the web when `web/sqlite3.wasm` and `web/drift_worker.js` are served.
- `lib/ai/key_store.dart` imports `dart:io` and `package:win32` (FFI), which blocks
  web compilation even though own keys are hidden on the web.
- Ten more files import `dart:io`, mostly for `on SocketException`.
- `lib/data/recipe_photo_store.dart` (`FileRecipePhotoStore`) and
  `lib/features/recipes/voice_recorder.dart` use files and directories.
- `lib/app/app.dart:73` and `:84` talk to native window channels on macOS/Windows by
  `defaultTargetPlatform`. In a Mac browser that check is also `macOS`, so the web
  build must skip it.
- `lib/providers.dart:86` listens to `AppLinks()`; there are no `tavli://` links on the web.
- App-called server functions: `ai-gateway`, `cookbook-ask`, `cookbook-process`,
  `delete-account`, `household-invite`, `household-join`, `planning-inputs`,
  `voice-transcribe`. None handles `OPTIONS` or sends CORS headers. Supabase Auth,
  REST, Storage and Realtime already answer browsers.
- `wrangler.jsonc` deploys `site/` as the `welcome` Worker; `site/_headers` holds
  a strict CSP for that site.
- `TavliPlatform.fromTarget` uses `defaultTargetPlatform`, so iPhone Safari gets the
  iOS look and Mac browsers the macOS look, as in the native apps.

## Constitution Check

| Principle | Status | Evidence |
| --- | --- | --- |
| I Serbian UI; English engineering docs | Pass | New copy is in spec.md UI table; docs English |
| II Offline, account ownership, privacy exceptions | Pass with design | Same drift cache + outbox per account in origin storage; two-account test in one browser (SC-006) |
| III AIRouter and validated AI | Pass | Web uses the existing gateway transport through AIRouter; own-key clients never constructed on web (D2) |
| IV Secrets and safe diagnostics | **Blocked until amendment** | Session in browser storage needs the D1 exception; no keys in build; CSP required. Amendment task is a Ready gate |
| V Test-first; local backend tests | Pass with tasks | Deno CORS tests (allowed, foreign, missing session); web photo store tests; `flutter test --platform chrome` for web-only units |
| VI Responsive/accessibility | Pass with tasks | Same layouts; validate phone/wide/2× text/reduced motion in Safari and Chrome |
| VII Reviewable changes/generated files | Pass | Four slices below; no generated-file changes expected |
| VIII Canonical spec, branches from dev | **Deviation recorded** | Branch cut from `origin/main` at owner's request; tree identical to dev; PR targets dev |
| IX Existing architecture and guardrails | Pass | No new folders in `lib/`; web files only in new `web/`; no new packages |
| X Shared contracts and human review | Pass with coordination | CORS touches Dev 2 (gateway, cookbooks, planning) and Dev 3 (household, account) functions; constitution change needs review |

## File and responsibility map

| Existing/new path | Change | Owner | Consumer/reviewer |
| --- | --- | --- | --- |
| `web/` (new: `index.html`, `manifest.json`, `icons/`, `sqlite3.wasm`, `drift_worker.js`) | New web target, PWA metadata, Tavli icons and colours | Dev 4 | Dev 3 |
| `web/_headers` (new, copied into the build) | CSP, `no-store` for `index.html`/service worker, `nosniff` | Dev 4 | Dev 3 (012) |
| `lib/ai/key_store.dart` | Move `win32`/`dart:io` parts behind a conditional import; native file content unchanged in behaviour | Dev 4 | Dev 2 |
| `lib/ai/key_store.dart` (`NoOwnKeyStore`), `secret_storage_errors*.dart` (new) | Web uses a store with no own keys (D2); the session stays in `SessionStore` over secure storage (D1) | Dev 4 | Dev 2 |
| `lib/data/socket_exception*.dart` (new) | Conditional `SocketException`: the real one from `dart:io`, a never-thrown stub on web (web network failures are already caught as `http.ClientException`) | Dev 4 | owners of the 7 callers |
| `lib/ai/speech_transcriber.dart`, `recipe_semantic_search.dart`, `lib/sync/sync_remote.dart`, `lib/account/account_api.dart`, `auth_gateway.dart`, `lib/data/planning_sharing_repository.dart`, `cookbook_repository.dart` | `on SocketException` → helper; same mapped errors | Dev 4 | Dev 2, Dev 3 |
| `lib/data/recipe_photo_store.dart`, `file_recipe_photo_store.dart` (moved unchanged), `indexed_db_recipe_photo_store.dart`, `recipe_photo_store_platform*.dart` (new) | Web store keeps bytes in IndexedDB keyed by the validated relative path; native `FileRecipePhotoStore` unchanged; `file()` is no longer on the interface | Dev 4 | Dev 1/Dev 2 (recipes) |
| `lib/features/recipes/recipe_providers.dart`, `recipe_photo.dart`, `recipe_photo_image*.dart` | Pick store by platform; native keeps `Image.file`, web uses `Image.memory` | Dev 4 | Dev 2 |
| `lib/features/recipes/voice_recorder.dart`, `voice_recorder_io.dart` (moved unchanged), `voice_recorder_web.dart` | Web records WAV to a blob; native path unchanged | Dev 4 | Dev 4 |
| `lib/app/app.dart` | `!kIsWeb &&` guard on the macOS/Windows window channels | Dev 4 | Dev 3 |
| `lib/providers.dart` | No `AppLinks` stream on web; web key store selection | Dev 4 | coordinator Dev 4 |
| `lib/account/auth_gateway.dart` | `emailRedirectTo` on web = environment web confirmation URL (dart-define) | Dev 4 | Dev 3 |
| `lib/features/settings/ai_keys_screen.dart` | On web show the D2 notice instead of the key list | Dev 4 | Dev 2 |
| `lib/data/database.dart` | `web:` options for the drift worker only; **no schema change** | Dev 4 | Dev 1 |
| `supabase/functions/_shared/cors.ts` (new, `withCors` wrapper) + 7 app-called `index.ts` | Origin allowlist from env `TAVLI_WEB_ORIGINS`, `OPTIONS` preflight, headers on every response | Dev 4 | Dev 2, Dev 3 |
| `supabase/config.toml` | Add local web origin to `additional_redirect_urls` | Dev 4 | Dev 3 |
| `.github/workflows/deploy-web.yml` (new) | On push to `main`: build web with production values from the `production` environment, deploy `build/web` as a Cloudflare Worker | Dev 4 | Dev 3 |
| `.github/workflows/check.yml` | `web-build` job: `flutter build web --wasm --release`, no secrets | Dev 3 (CI owner) | Dev 4 |
| new `web.wrangler.jsonc` | Static-assets Worker `tavli-web` for `build/web`, same pattern as `wrangler.jsonc` (research R7) | Dev 4 | Dev 3 |
| `.specify/memory/constitution.md` | Web target in platform list; IV exception for web session (D1) | Dev 4 | independent reviewer |
| `docs/architecture.md`, `AGENTS.md` (commands) | Web target and commands | Dev 4 | Dev 3 |

**Not touched**: `ios/`, `macos/`, `android/`, `windows/`, `linux/`, `packages/tavli_ui` (unless a
web-only guard proves necessary, coordinated with 031).

## Contracts and data changes

- [contracts/cors.md](contracts/cors.md): server function browser access contract.
- [contracts/web-platform.md](contracts/web-platform.md): web-only behaviour of key store,
  photo store, redirect and hidden features.
- [data-model.md](data-model.md): web photo cache and session storage.

Server: no new tables, RLS or migrations. Client: **no drift schema change**; the web photo
cache is IndexedDB (research R4, decided), so no `schemaVersion` bump collides with other
in-flight migrations.

## Dependencies and delivery order

New dependencies: **two direct declarations, no new package**: `web ^1.1.1` (IndexedDB for recipe photos, already locked as a Flutter dependency) and `sqlite3 ^3.9.1` (already locked as a
transitive dependency of drift at 3.9.1). Reason: `lib/sync/downloader.dart` imported
`package:drift/native.dart` only for `SqliteException`, which pulls in `dart:ffi` and breaks web
compilation; `package:sqlite3/common.dart` exports the same class without FFI. drift's `sqlite3.wasm` and `drift_worker.js` are build assets
of existing packages; conditional imports use `dart.library.js_interop` from the SDK.

| Slice | Content | Visible result | Effort / confidence |
| --- | --- | --- | --- |
| 1 Compile & host | `web/`, conditional imports (key store, network errors, app links, window channels), drift worker, redirect URL, `_headers`, Cloudflare dev deploy, CI `web-build` | Installable Tavli on iPhone/Mac; sign-in, plans, shopping, pantry, offline | 2–3 days / medium |
| 2 Browser access to functions | `_shared/cors.ts`, 8 functions, Deno tests, env origins | AI recipes, planning inputs, household join, cookbooks, account delete work in browser | 1–2 days / high |
| 3 Photos, voice, media | Web photo store, voice blob, QR/camera/share/wakelock checks, D2 key screen notice | Recipe photos and voice on web; unsupported features explained | 2–3 days / medium |
| 4 Governance & evidence | Constitution amendment, architecture/AGENTS docs, device validation on iPhone and Mac, 012 review | Ready for acceptance | 1–2 days + review |

Slices 1 and 2 can be reviewed independently; slice 2 touches other owners' functions
and needs their review. Each slice is its own PR into `dev`.

## Validation and rollout

- Gates: `scripts/check.sh`, full `flutter test`, `flutter test --platform chrome` for
  web-only units, `flutter build web --wasm --release`, `flutter build macos --debug`
  (native untouched), `deno test` for functions, `python3 scripts/check-docs.py`.
- Local: `supabase start`, `flutter run -d chrome --dart-define-from-file=secrets.json`,
  then `flutter build web` served locally and opened from iPhone Safari on the LAN for
  install checks (see [quickstart.md](quickstart.md)).
- Device matrix: iPhone (current iOS, Safari, home screen), macOS Safari 17+ and Chrome;
  phone and wide width, 2× text, reduced motion, offline start, two accounts.
- Rollout: merge to `dev`; function changes deploy through `deploy-supabase.yml` as today.
  Hosted environment configuration is handled outside the repository documents.
  The web app targets the production backend (D3): it ships only through the release PR
  `dev` → `main` and the `production` approval (`.github/workflows/deploy-web.yml`).
- Recovery: web deploys are atomic per Cloudflare version; roll back by redeploying the
  previous build. Native clients are unaffected by CORS changes (they send no `Origin`).

## Complexity Tracking

| Deviation / risk | Why needed | Simpler option | Resolution / owner |
| --- | --- | --- | --- |
| Web app talks to production only | Owner decision, no real users yet, no separate dev web build | Dev web build | Additive changes only; release gate; native clients unaffected by CORS | Anja |
| Branch from `main`, not `dev` | Owner request | Branch from dev | Trees identical at baseline; PR into dev; Anja |
| Session in browser storage | Users must stay signed in (D1) | In-memory session | Constitution IV exception + CSP; independent review |
| Safari may evict storage of non-installed sites | Platform behaviour | None | Recover via sign-in + download; notice for lost unsent changes |
| Drift wasm mode differs by browser | Safari lacks SharedArrayBuffer without COOP/COEP | Force IndexedDB | Accept drift's automatic choice; test both Safari and Chrome (R3) |

## Security implementation impact

| Threat | Boundary | Control | Negative test | Owner |
| --- | --- | --- | --- | --- |
| XSS steals web session | Tavli web origin | CSP `script-src 'self' 'wasm-unsafe-eval'`, `connect-src` only env Supabase; no third-party scripts | CSP header test on built `_headers`; manual check of blocked inline script | Dev 4 |
| Foreign site calls functions with a user's token | Server functions | Exact-match origin allowlist; auth unchanged | Foreign `Origin` → no ACAO header; missing bearer → 401 with allowed origin | Dev 4 / Dev 2, 3 |
| Personal data in caches | Service worker | Cache only static build files; API never cached | Inspect cache storage after sync | Dev 4 |
| Own key leakage in browser | Web key store | Own keys never stored or read on web (D2) | Web key store returns empty and rejects writes | Dev 4 |
| Cross-account data in one browser | drift per-account cache | Existing account scoping | Two-account test (SC-006) | Dev 4 |
| Photo path traversal | Photo store | Same relative-path validation as native | Invalid path rejected in web store test | Dev 4 |

Hosted settings are not described here and this plan does not claim they are configured.
Functions read allowed origins from the environment and allow none when it is unset.
No production probes.
