# Tasks: AI keys list

**Input**: [spec.md](spec.md), [plan.md](plan.md). Tests first (constitution V).

## Phase 1: Foundational

- [x] T001 Test: `detectProvider` prefixes; `InMemoryKeyStore` add/list/remove/duplicate; `SecureKeyStore` legacy migration logic (via a fake storage) in `test/ai/key_store_test.dart`
- [x] T002 Implement `StoredKey`, `KeyStore`, `SecureKeyStore`, `InMemoryKeyStore`, `detectProvider` in `lib/ai/key_store.dart`
- [x] T003 Test: key source returns own keys in add order then built-in, with key ids, in `test/ai/key_source_test.dart`
- [x] T004 Test: router tries second own key on 429 of the first; rejected key skipped alone; `invalidKeyIds` in `test/ai/ai_router_test.dart`
- [x] T005 Implement per-key slots in `ai_router.dart`, `model_status_store.dart`, `drift_model_status_store.dart`

## Phase 2: User Stories 1–2 (P1)

- [x] T006 [US1][US2] Widget tests: generic field label, detect + add, unknown prefix asks for service, rejected key not saved, unchecked key saved, duplicate refused, list with masked keys, delete with confirm, no built-in keys shown, in `test/features/ai_keys_screen_test.dart`
- [x] T007 [US1][US2] Rewrite `lib/features/settings/ai_keys_screen.dart`

## Phase 3: Polish

- [x] T008 Update `docs/architecture.md`; `scripts/check.sh`; `flutter build macos --debug`; spec status → Implemented

## Analysis (/speckit-analyze, 2026-10-30)

| FR | Tasks |
|---|---|
| FR-001 generic field | T006, T007 |
| FR-002 prefix detection / choose | T001, T002, T006 |
| FR-003 check before save | T006, T007 |
| FR-004 many keys, no duplicates | T001, T002, T006 |
| FR-005 list, masked, check, delete | T006, T007 |
| FR-006 never shown/logged | T002 (`toString` without value), T006 (only last 4 on screen) |
| FR-007 per-key fallback order | T003, T004, T005 |
| FR-008 legacy migration | T001, T002 |
| FR-009 built-in keys hidden, no "Probaj AI" section | T006, T007 |

No constitution conflicts; no schema change (text column reused); terminology: "service" in UI = `AIProvider`.
