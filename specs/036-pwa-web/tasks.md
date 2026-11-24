# Tasks: Installable web app (PWA) for iOS and macOS

**Spec / plan**: [spec.md](spec.md), [plan.md](plan.md) | **Branch / baseline**: `036-pwa-web` / `origin/main` `5b37b9a`
**Owner / reviewer**: Anja (Dev 4) / Matija (Dev 3), proposed | **Feature key / Trello**: none yet

Additive only: no task edits `ios/`, `macos/` or their settings. Native code is
moved, never changed in behaviour. Checkboxes mean the result exists in this branch;
Done requires independent review and a merged PR. Device checks stay open until run.

## Slice 1 — Compile, install and sign in (US1, US2, US4)

- [x] T001 [US1] Add `web/` target: `index.html`, `manifest.json`, icons from existing branding assets, drift `sqlite3.wasm` + `drift_worker.js`. Owner: Dev 4; reviewer: Dev 3; FR-002; depends: none; done: `flutter build web --wasm --release` produces an installable bundle.
- [x] T002 [US1] Web-safe `KeyStore`: conditional import, native file unchanged (moved to `key_store_io.dart`), `key_store_web.dart` stores the session only and no own keys. Owner: Dev 4; reviewer: Dev 2; FR-010, FR-011; depends: none; done: web key store tests pass in Chrome, native tests unchanged.
- [x] T003 [US2] Network-error helper `lib/data/network_errors.dart`; replace `on SocketException` in 7 callers. Owner: Dev 4; reviewer: callers' owners; FR-009; depends: none; done: existing offline mapping tests pass; web variant tested.
- [x] T004 [US1] Guard macOS/Windows window channels in `lib/app/app.dart` with `!kIsWeb`; empty app-links stream on web in `lib/providers.dart`. Owner: Dev 4; reviewer: Dev 3; FR-001; depends: none; done: web app starts in Chrome without channel errors.
- [x] T005 [US1] Web sign-in redirect: `WEB_AUTH_REDIRECT_URL` dart-define used on web; local origin added to `supabase/config.toml` redirect list. Owner: Dev 4; reviewer: Dev 3; FR-005; depends: T001; done: email code sign-in works on web against local stack.
- [x] T008 [US1] `web.wrangler.jsonc` and `.github/workflows/deploy-web.yml` (production only, `production` environment approval). Owner: Dev 4; reviewer: Dev 3; FR-012; depends: T006; done: workflow reviewed; first run after release PR approval.
- [x] T006 [US1] `web/_headers` with CSP, `no-cache` for shell files; CI `web-build` job. Owner: Dev 4 / Dev 3 (CI); reviewer: Dev 3; FR-013, security; depends: T001; done: CI job green without secrets.
- [ ] T007 [US4] Validate install on iPhone Safari and macOS Safari/Chrome per [quickstart.md](quickstart.md); record results in the PR description. Owner: Dev 4; reviewer: Dev 3; SC-001..003; depends: T001–T006; done: evidence linked.

## Slice 2 — Browser access to server functions (US3)

- [x] T010 [US3] Failing Deno tests for the CORS contract ([contracts/cors.md](contracts/cors.md)). Owner: Dev 4; reviewer: Dev 2; FR-006; depends: none; done: tests fail without helper.
- [x] T011 [US3] `supabase/functions/_shared/cors.ts` and use in the 7 app-called functions. Owner: Dev 4; reviewer: Dev 2, Dev 3; FR-006; depends: T010; done: `deno test` green, native responses byte-identical.

## Slice 3 — Photos, voice and media (US3, US5)

- [x] T020 [US3] Web `RecipePhotoStore` (bytes) with path-validation tests; provider selection. Owner: Dev 4; reviewer: Dev 2; FR-007; depends: T001; done: tests in Chrome, photo survives restart.
- [x] T021 [US5] Voice recorder web branch; QR/camera/share/wakelock checks with Serbian fallbacks. Owner: Dev 4; reviewer: Dev 3; FR-008; depends: T001; done: each feature works or explains itself on Safari and Chrome.
- [x] T022 [US3] AI keys screen on web shows the D2 notice. Owner: Dev 4; reviewer: Dev 2; FR-011; depends: T002; done: widget test.

## Slice 4 — Governance and evidence

- [x] T030 Constitution amendment: web target and session exception (principle IV). Owner: Dev 4; reviewer: independent; FR-010; depends: none; done: reviewed text.
- [x] T031 Update `docs/architecture.md` and `AGENTS.md` commands; run `python3 scripts/check-docs.py`. Owner: Dev 4; reviewer: Dev 3; depends: slice 1; done: docs check green.
- [ ] T032 Two-account-in-one-browser check (SC-006) and 012 security review. Owner: Dev 4; reviewer: Dev 3; depends: slice 1–3; done: evidence linked.

## Dependencies and effort

| Slice | Blocked by | Implementation | Tests | Review/integration | Confidence |
| --- | --- | --- | --- | --- | --- |
| 1 | none | 2–3 days | 0.5 day | 1 day | medium |
| 2 | none (parallel) | 1 day | 0.5–1 day | 1 day | high |
| 3 | slice 1 | 2 days | 1 day | 1 day | medium |
| 4 | slices 1–3 | 1 day | 0.5 day | review wait | medium |

External setup (Cloudflare token, function environment values, Supabase production
redirect URLs) is handled outside this document and is not claimed done.
