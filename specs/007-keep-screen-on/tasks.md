# Tasks: Keep the screen on while cooking

Tests first (constitution V).

- [x] T001 Add `wakelock_plus` (justified in plan.md)
- [x] T002 Tests: setting default off, persisted; toggle shows messages; wake lock on while recipe open with setting on, off after leaving; remembered for next recipe; wide split; platform failure ignored — `test/features/recipes/keep_screen_on_test.dart`
- [x] T003 Implement `keep_screen_on.dart`, wire into `recipe_detail_screen.dart`, fake in `test/helpers/test_app.dart`
- [x] T004 `scripts/check.sh`, `flutter build macos --debug`, docs, spec status → Implemented

## Analysis (/speckit-analyze, 2026-10-30)

| FR | Tasks |
|---|---|
| FR-001 toggle | T002, T003 |
| FR-002 keep on while open | T002, T003 |
| FR-003 release on leave | T002, T003 |
| FR-004 stored, default off | T002, T003 |
| FR-005 failures ignored | T002, T003 |

No conflicts; no schema change.
