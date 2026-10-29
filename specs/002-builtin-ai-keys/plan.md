# Implementation Plan: Built-in Tavli AI keys

**Branch**: `002-builtin-ai-keys` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-builtin-ai-keys/spec.md`

## Summary

Add optional built-in provider keys, compiled in from a gitignored
`secrets.json` via `--dart-define-from-file`. A new `KeySource` returns an
ordered list of credentials per provider (own key from `KeyStore` first, then
built-in). `AIRouter` loops over credentials inside each model, and tracks
pauses, rejected keys and missing models per (model, key origin). Pauses
persist in drift with a new `keyOrigin` column (schema v2). The AI keys screen
shows "Koristi se ugrađeni Tavli AI"; the chain test log marks "Tavli AI".

## Technical Context

**Language/Version**: Dart ≥ 3.13, Flutter
**Primary Dependencies**: existing only — flutter_riverpod, drift, dio, flutter_secure_storage (no new packages)
**Storage**: drift, `ModelStatuses` gains `keyOrigin`; `schemaVersion` 1 → 2
**Testing**: flutter_test; fake `ChatClient`, in-memory stores, `NativeDatabase.memory()`
**Target Platform**: Android, iOS, macOS
**Project Type**: mobile/desktop app (single Flutter project)
**Performance Goals**: at most one extra request per model when the own key is limited
**Constraints**: keys never logged or displayed; tests never need real keys
**Scale/Scope**: 3 providers × 2 key origins

## Constitution Check

*GATE: passed before Phase 0, re-checked after Phase 1.*

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ new copy: "Koristi se ugrađeni Tavli AI", "Tavli AI" |
| II. Offline-first | ✅ schema bump with migration (v1 → v2) |
| III. AI only via AIRouter | ✅ router owns key fallback; no provider-specific code in features |
| IV. Secrets never committed | ✅ `secrets.json` gitignored; `secrets.example.json` has empty values; built-in key never displayed |
| V. Test-first | ✅ key source, router per-origin behaviour, drift store, keys screen tested first |
| VI. Responsive | ✅ only text added to existing cards |
| VII. Small commits | ✅ commit per Spec Kit phase / task group |
| VIII. One feature = one spec branch | ✅ `002-builtin-ai-keys` |

## Project Structure

### Documentation (this feature)

```text
specs/002-builtin-ai-keys/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/key-source.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
lib/ai/key_store.dart              + KeyOrigin, ApiCredential, KeySource, BuiltInKeys, LayeredKeySource
lib/ai/ai_router.dart              credentials loop, per-origin state, AIResult.origin
lib/ai/ai_errors.dart              AttemptLog.origin
lib/ai/model_status_store.dart     origin parameter
lib/data/database.dart             ModelStatuses.keyOrigin, schemaVersion 2 + migration
lib/data/drift_model_status_store.dart  origin-aware
lib/providers.dart                 builtInKeysProvider, keySourceProvider
lib/features/settings/ai_keys_screen.dart   "Koristi se ugrađeni Tavli AI"
lib/features/settings/chain_test_card.dart  "Tavli AI" mark in log
secrets.example.json               empty placeholders
test/ai/key_source_test.dart       new
test/ai/ai_router_test.dart        new per-origin cases
test/data/drift_model_status_store_test.dart  new
test/features/ai_keys_screen_test.dart       new cases
```

**Structure Decision**: single Flutter project; changes stay in the existing `ai/`, `data/`, `features/settings/` layers.

## Complexity Tracking

None.
