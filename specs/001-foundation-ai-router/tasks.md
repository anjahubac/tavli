# Tasks: Foundation — app shell, database and AI router

**Input**: [spec.md](spec.md), [plan.md](plan.md) — backfilled; all tasks done.

## Phase 1: Setup

- [x] T001 Create Flutter project for Android, iOS, macOS (`469262a`)
- [x] T002 Add dependencies: flutter_riverpod, go_router, dio, flutter_secure_storage, drift, drift_flutter, path_provider, image_picker; dev: build_runner, drift_dev
- [x] T003 Platform config: network permission (Android), photo/camera usage strings (iOS), network client + user-selected read-only file entitlements (macOS)

## Phase 2: Foundational

- [x] T004 Drift schema with all tables in `lib/data/database.dart`; generate `database.g.dart`
- [x] T005 [P] Recipe domain model + AI JSON parsing in `lib/domain/recipe.dart`
- [x] T006 [P] Test: recipe parsing (full recipe, fractions, unknown category, missing title/ingredients, round-trip) in `test/domain/recipe_test.dart`
- [x] T007 Riverpod wiring in `lib/providers.dart`

## Phase 3: User Story 1 — Navigation (P1)

- [x] T008 [US1] Test: phone bottom tabs and switching to Ostava; wide-screen rail in `test/app/home_shell_test.dart`
- [x] T009 [US1] `TavliApp`, `appRouter` (StatefulShellRoute, five tabs) and `HomeShell` in `lib/app/`
- [x] T010 [US1] `PlaceholderScreen` ("Uskoro") for unbuilt tabs

## Phase 4: User Story 3 — Resilient AI (P1)

- [x] T011 [P] [US3] Models and errors: `ai_models.dart`, `ai_errors.dart`
- [x] T012 [US3] Test: client request shape, 429 with Retry-After/daily, Gemini retryDelay, status mapping, 5xx retry, empty response in `test/ai/chat_client_test.dart`
- [x] T013 [US3] `OpenAICompatibleClient` + `mapDioException` in `lib/ai/chat_client.dart`
- [x] T014 [US3] Default vision/text chains in `lib/ai/chain_config.dart`
- [x] T015 [US3] `ModelStatusStore` interface + in-memory impl; `DriftModelStatusStore`
- [x] T016 [US3] `KeyStore` interface, `SecureKeyStore`, `InMemoryKeyStore`
- [x] T017 [US3] Test: router scenarios (first-success, 429 fallback, paused skip, daily reset 08:00 UTC, 60 s minute pause, bad key, no key, 404, JSON retry, vision chain, parse error stops chain, request counting, chain JSON round-trip) in `test/ai/ai_router_test.dart`
- [x] T018 [US3] `AIRouter` + `decodeJsonObject` in `lib/ai/ai_router.dart`
- [x] T019 [US3] Prompts (Serbian output, recipe JSON schema) in `lib/ai/prompts.dart`
- [x] T020 [US3] `RecipeAI` (fromImage, fromDishName, refine, model stamping) in `lib/ai/recipe_ai.dart`

## Phase 5: User Story 2 — AI keys screen (P1)

- [x] T021 [P] [US2] Test: chain model availability check in `test/ai/model_check_test.dart`
- [x] T022 [US2] `checkChainModels` in `lib/ai/model_check.dart`
- [x] T023 [US2] Dio fake adapter in `test/helpers/fake_adapter.dart`
- [x] T024 [US2] Test: save + check key, wrong key message, delete key in `test/features/ai_keys_screen_test.dart`
- [x] T025 [US2] `ProfileScreen` and `/profile/ai-keys` route
- [x] T026 [US2] `AiKeysScreen` with per-provider key cards
- [x] T027 [US2] `ChainTestCard` (sample recipe + attempt log, nothing saved)
- [x] T028 [US2] Serbian error messages in `aiErrorText`

## Phase 6: Polish

- [x] T029 `flutter analyze` clean, `flutter test` green (33 tests)
