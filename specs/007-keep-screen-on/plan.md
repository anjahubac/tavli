# Implementation Plan: Keep the screen on while cooking

**Branch**: `007-keep-screen-on` (from latest `main`) | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

## Summary

`KeepScreenOn` notifier stores the choice in the existing `AppSettings` table
(key `keep_screen_on`). `KeepScreenOnScope` wraps the recipe detail and turns a
platform wake lock on/off from that value; it releases it on dispose. A toggle
`IconButton` in the recipe app bar flips the setting.

## Technical Context

**Dependencies**: new `wakelock_plus` — keeps the display awake on Android, iOS and macOS behind one API (Flutter has no built-in way). Wrapped in a `ScreenWakeLock` interface so tests use a fake.
**Storage**: `AppSettings` row, no schema change.
**Testing**: widget tests with a fake wake lock and in-memory DB (phone and wide).

## Constitution Check

| Principle | Status |
|---|---|
| I. Serbian UI | ✅ copy in spec |
| II. Offline-first | ✅ setting in drift, no schema change |
| III. AI via router | ✅ n/a |
| IV. Secrets | ✅ n/a |
| V. Test-first | ✅ notifier + widget tests first |
| VI. Responsive | ✅ toggle in detail app bar, also in wide split |
| VII. Small commits | ✅ |
| VIII. One spec branch | ✅ from latest main |
| IX. Guardrails | ✅ one justified dependency |

## Source Code

```text
lib/features/recipes/keep_screen_on.dart     ScreenWakeLock, KeepScreenOn notifier, KeepScreenOnScope, toggle button
lib/features/recipes/recipe_detail_screen.dart  toggle + scope
test/features/recipes/keep_screen_on_test.dart
test/helpers/test_app.dart                   fake wake lock override
```
