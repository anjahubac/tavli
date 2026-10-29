# Implementation Plan: Foundation — app shell, database and AI router

**Branch**: `001-foundation-ai-router` (as `feat/foundation-ai-router`) | **Date**: 2026-10-30 (backfilled) | **Spec**: [spec.md](spec.md)

## Summary

Flutter app skeleton with a responsive five-tab shell, a drift schema covering
all planned data, and an AI layer: one OpenAI-compatible dio client, an
`AIRouter` with vision/text fallback chains and persisted cooldowns, and a
`RecipeAI` façade. A settings screen manages provider keys in secure storage
and tests the chain.

## Technical context

- **Language**: Dart ≥ 3.13, Flutter, Material 3
- **Dependencies**: flutter_riverpod 3 (state/DI), go_router 18 (StatefulShellRoute),
  drift + drift_flutter (SQLite), dio (HTTP), flutter_secure_storage (keys),
  path_provider, image_picker (for upcoming photo import); dev: build_runner, drift_dev, flutter_lints
- **Storage**: local SQLite `tavli`, schemaVersion 1
- **Testing**: flutter_test; fake `ChatClient`, `fake_adapter.dart` for dio, in-memory stores
- **Platforms**: Android, iOS, macOS (macOS: network client + user-selected file entitlements; classic keychain so unsigned debug builds work)
- **Constraints**: free AI tiers only; offline use of stored data

## Constitution check

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ all labels/messages Serbian (Latin); prompts require Serbian output |
| II. Offline-first | ✅ drift schema for all data; AI is the only network use |
| III. AI via AIRouter | ✅ `RecipeAI` → `AIRouter` → `ChatClient`; models only in `ChainConfig` |
| IV. Secrets | ✅ `SecureKeyStore`; tests use `InMemoryKeyStore` |
| V. Test-first | ✅ router, client, recipe parsing, model check, shell, keys screen tested |
| VI. Responsive | ✅ bottom tabs < 720 px, rail ≥ 720 px |
| VII. Small commits | ✅ two feature commits |
| VIII. Spec per feature | ⚠️ backfilled after implementation (Spec Kit adopted later) |

## Project structure

```
lib/ai/        ai_models, ai_errors, chat_client, chain_config, ai_router,
               model_status_store, key_store, model_check, prompts, recipe_ai
lib/app/       app, router, home_shell, placeholder_screen
lib/data/      database (+ .g.dart), drift_model_status_store
lib/domain/    recipe
lib/features/settings/  profile_screen, ai_keys_screen, chain_test_card, ai_error_text
lib/providers.dart
test/ai/       ai_router_test, chat_client_test, model_check_test
test/app/      home_shell_test
test/domain/   recipe_test
test/features/ ai_keys_screen_test
test/helpers/  fake_adapter
```

## Key design decisions

- **One client, three providers**: all expose OpenAI-compatible `/chat/completions`
  and `/models`; provider-specific quirks (Gemini 400 "API key", `retryDelay` in body,
  `models/` prefix) handled in error mapping / model check.
- **Router state**: cooldowns persisted (survive restart); invalid keys and missing
  models kept in memory and reset when a new key is saved.
- **Cooldown rules**: Retry-After → that; minute limit → 60 s; daily limit → model's
  `dailyResetUtcHour` (Gemini 08:00 UTC) else 1 h.
- **JSON robustness**: `decodeJsonObject` extracts the outermost `{…}`; parse errors
  get one retry on the same model.
- **Chain config as a function** so a future settings screen can change it live.
- **Lists as JSON columns** in drift rows (always read with the parent).

## Complexity tracking

None.
