# Implementation Plan: AI keys list

**Branch**: `004-ai-keys-list` (stacked on `003-recipe-screens`) | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

## Summary

`KeyStore` changes from one key per provider to a list of `StoredKey`
(id, provider, value, addedAt) kept as one JSON entry `api_keys` in secure
storage; legacy `api_key_<provider>` entries are migrated on first read.
`ApiCredential` gains `keyId`; `LayeredKeySource` returns all own keys of a
provider in add order, then the built-in key. `AIRouter` and the model status
store key their state by origin + key id (`user:<id>`), so each key has its own
pauses. The AI keys screen becomes one add form + a list of saved keys.

## Technical Context

**Language/Version**: Dart ≥ 3.13, Flutter
**Primary Dependencies**: existing only (flutter_secure_storage, riverpod, dio)
**Storage**: secure storage entry `api_keys` (JSON list); drift `ModelStatuses.keyOrigin` text now holds `user:<id>` for own keys — no schema change (old `user` rows expire within a day)
**Testing**: flutter_test; `InMemoryKeyStore`, fake chat client, `FakeAdapter`
**Target Platform**: Android, iOS, macOS

## Constitution Check

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ copy in spec |
| II. Offline-first | ✅ no schema change; key list local |
| III. AI only via AIRouter | ✅ router keeps fallback; per-key slots |
| IV. Secrets never committed | ✅ keys only in secure storage; UI shows last 4; tests use fake values |
| V. Test-first | ✅ prefix detection, key store migration, key source order, router per-key tests first |
| VI. Responsive | ✅ single column, widget tests at phone and wide |
| VII. Small commits | ✅ store/router commit, screen commit |
| VIII. One spec branch | ✅ `004-ai-keys-list` (stacked; PR after #1) |
| IX. Guardrails | ✅ no new deps, check.sh |

## Source Code

```text
lib/ai/key_store.dart            StoredKey, KeyStore (list/add/remove), SecureKeyStore (+ legacy migration), detectProvider, ApiCredential.keyId
lib/ai/model_status_store.dart   keyId parameter
lib/data/drift_model_status_store.dart  keyId → keyOrigin "user:<id>"
lib/ai/ai_router.dart            per-key slots; invalidKeyIds
lib/features/settings/ai_keys_screen.dart  add form + saved key list
test/ai/key_store_test.dart, key_source_test.dart, ai_router_test.dart, test/features/ai_keys_screen_test.dart
```

## Complexity Tracking

None.
