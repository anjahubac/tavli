# Tasks: Built-in Tavli AI keys

**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/key-source.md](contracts/key-source.md)
**Tests**: required (constitution V) — write each test task before its implementation task and see it fail.

Format: `[ID] [P?] [Story] Description` — `[P]` = can run in parallel (different files).

## Phase 1: Setup

- [x] T001 Add `secrets.example.json` (empty values) at repo root and whitelist it in `.gitignore` (`!secrets.example.json`)

## Phase 2: Foundational (blocks all stories)

- [x] T002 [P] Test: `LayeredKeySource` order (own then built-in), empty values dropped, no keys → empty list in `test/ai/key_source_test.dart`
- [x] T003 Add `KeyOrigin`, `ApiCredential`, `KeySource`, `BuiltInKeys` (`fromEnvironment`), `LayeredKeySource` in `lib/ai/key_store.dart`
- [x] T004 Add `origin` to `ModelStatusStore` methods and `InMemoryModelStatusStore` in `lib/ai/model_status_store.dart`
- [x] T005 Test: drift store keeps pauses separately per origin; migration v1 → v2 opens cleanly, in `test/data/drift_model_status_store_test.dart`
- [x] T006 Add `keyOrigin` column + PK to `ModelStatuses`, `schemaVersion` 2 with migration in `lib/data/database.dart`; regenerate `database.g.dart`
- [x] T007 Make `DriftModelStatusStore` origin-aware in `lib/data/drift_model_status_store.dart`
- [x] T008 Add `origin` to `AttemptLog` (`lib/ai/ai_errors.dart`) and `AIResult` (`lib/ai/ai_router.dart`)

## Phase 3: User Story 1 + 2 — built-in key works, own key first (P1)

- [x] T009 [US1][US2] Tests in `test/ai/ai_router_test.dart`: only built-in key works; own key used first; own 429 → same model with built-in; own paused → skipped while built-in used; built-in pause does not affect own; own key rejected → built-in still used and `invalidProviders` contains provider; built-in rejected → not in `invalidProviders`; `nextAvailableAt` considers both origins; `resetProvider` clears only own-key state
- [x] T010 [US1][US2] `AIRouter` takes `KeySource`; inner credential loop; per-origin rejected/missing/paused state in `lib/ai/ai_router.dart`
- [x] T011 [US1] `builtInKeysProvider` + `keySourceProvider`; router uses key source in `lib/providers.dart`

## Phase 4: User Story 3 — show which AI is used (P2)

- [x] T012 [US3] Widget tests in `test/features/ai_keys_screen_test.dart`: "Koristi se ugrađeni Tavli AI" shown with built-in and no own key; hidden with own key; hidden without built-in; chain test run with only a built-in key marks the attempt "Tavli AI" (FR-007)
- [x] T013 [US3] Show "Koristi se ugrađeni Tavli AI" on provider cards in `lib/features/settings/ai_keys_screen.dart`
- [x] T014 [US3] Mark built-in attempts "Tavli AI" in the chain test log in `lib/features/settings/chain_test_card.dart`

## Phase 5: Polish

- [x] T015 [P] Update `docs/architecture.md` (key source, per-origin cooldowns) and `AGENTS.md` (secrets.json run command)
- [x] T016 `scripts/check.sh` passes; `flutter build macos --debug` succeeds; spec status → Implemented

## Dependencies

T001 → none. T002 → T003. T004, T005 → T006 → T007. T003, T004, T008 → T009 → T010 → T011.
T011 → T012 → T013, T014. All → T015, T016.

## Analysis (/speckit-analyze, 2026-10-30)

| FR | Tasks |
|---|---|
| FR-001 built-in keys from local file | T001, T003, T011 |
| FR-002 own key first, then built-in | T009, T010 |
| FR-003 per-origin state | T004, T008, T009, T010 |
| FR-004 pauses persist per origin | T005, T006, T007 |
| FR-005 built-in rejection silent | T009, T010 |
| FR-006 keys screen text, key never shown | T012, T013 |
| FR-007 "Tavli AI" in log | T012, T014 |
| FR-008 replaceable key source | T003 (contract) |
| FR-009 example file, empty values | T001 |

Findings: one coverage gap (FR-007 had no test) fixed by extending T012. No
constitution conflicts, no unmapped tasks, terminology consistent (own/built-in = `user`/`builtIn`).
