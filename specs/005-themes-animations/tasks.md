# Tasks: Themes and ingredient animations

**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [research.md](research.md)
**Tests**: required (constitution V) — write each test task before its implementation task and see it fail.

Format: `[ID] [P?] [Story] Description` — `[P]` = can run in parallel (different files).

## Phase 1: Setup

- [x] T001 Bundle Plus Jakarta Sans (5 weights + OFL) in `assets/fonts/`, declare the family in `pubspec.yaml`

## Phase 2: Foundational (blocks all stories)

- [x] T002 [P] Test: `ThemeChoice` defaults, labels, `fromSettings` with unknown/missing values in `test/domain/theme_choice_test.dart`
- [x] T003 [P] Implement `lib/domain/theme_choice.dart`
- [x] T004 Test: `SettingsRepository` get/set, theme load (defaults on empty) and save round trip in `test/data/settings_repository_test.dart`
- [x] T005 Implement `lib/data/settings_repository.dart`
- [x] T006 Test: `buildTavliTheme` for all 6 combos — brightness, primary/surface/outlineVariant tokens, `TavliColors` present, font family, headings w800 in `test/app/theme_test.dart`
- [x] T007 Implement `lib/app/theme/tavli_palette.dart`, `tavli_colors.dart`, `app_theme.dart` (component themes per FR-006)

## Phase 3: User Story 1 — choose theme and mode (P1)

- [x] T008 [US1] Widget tests: default Bosiljak + system; Izgled → Šafran + Tamna recolours app and is stored; restart with stored choice uses it; phone and wide in `test/features/appearance_screen_test.dart`
- [x] T009 [US1] `lib/app/theme/theme_controller.dart`, `TavliApp` as ConsumerWidget, `lib/features/settings/appearance_screen.dart`, route `/profile/appearance`, Profil entry

## Phase 4: User Story 2 — consistent look (P1)

- [x] T010 [US2] Remove the seed colour; recipe list as bordered cards with tint thumbnails, search field 50/16, extended FAB radius 20 (copy "Dodaj recept" unchanged), nav bar top line in `home_shell.dart`; all screens use theme tokens only (grep check: no `Color(`/`Colors.` outside `lib/app/theme` and `lib/app/animations`)

## Phase 5: User Story 3 — AI waiting animations (P2)

- [x] T011 [US3] Test: `SimmeringPot` rotates messages, static with reduced motion; `PhotoScan` scan line runs while scanning, chips appear one by one in `test/app/animations_test.dart`
- [x] T012 [US3] `lib/app/animations/motion.dart`, `simmering_pot.dart`, `photo_scan.dart`
- [x] T013 [US3] Wire: `AiBusy` shows the pot (name, chat); photo screen shows `PhotoScan` while reading and ingredient chips on the preview; existing recipe tests stay green

## Phase 6: User Story 4 — intro and empty states (P2)

- [x] T014 [US4] Test: intro shows the active motif, fades after ≈1,8 s, tap skips; Ostava/Kupovina empty states; spoon refresh indicator appears on pull in `test/app/animations_test.dart` + `test/app/home_shell_test.dart`
- [x] T015 [US4] `intro_motif.dart`, `intro_overlay.dart`, `empty_fridge.dart`, `spoon_refresh.dart`; empty states in `placeholder_screen.dart`/router; spoon refresh on the recipes list

## Phase 7: User Story 5 — animations for later screens + gallery (P3)

- [x] T016 [US5] Test: `AnimatedCheckmark` draws in, `BumpBadge` bumps on change, `ShoppingBagFull`, `PlatePlanDrop`, `EggTimer` run and are static with reduced motion; gallery lists all nine names; Profil shows "Animacije" in debug in `test/app/animations_test.dart`, `test/features/animations_gallery_test.dart`
- [x] T017 [US5] `ingredient_check.dart`, `shopping_bag.dart`, `plate_drop.dart`, `egg_timer.dart`, `animations_gallery_screen.dart`, route `/profile/animations`

- [x] T017a [US5] Owner correction: ticked ingredient = "imam" (row softens, no flight, no badge); "Dodaj u kupovinu (N)" flies only unticked ingredients and bumps the badge by N; Kupovina empty copy "Sastojci koji ti nedostaju za recept pojaviće se ovde."; gallery test covers it

- [x] T017b [US5] Owner correction: "Dodaj u kupovinu" adds only the difference — `planRecipeShopping` (`lib/domain/shopping_sync.dart`) + `ShoppingRepository` (`lib/data/shopping_repository.dart`, existing tables, no schema change) + `shoppingRepositoryProvider`; "imam" removes this recipe's unbought item; tests: `test/domain/shopping_sync_test.dart`, `test/data/shopping_repository_test.dart`, gallery scenario test

## Phase 8: Polish

- [x] T018 Update `docs/architecture.md` (theme + animations), `docs/roadmap.md`, `AGENTS.md` structure
- [x] T019 `scripts/check.sh` green; `flutter build macos --debug` succeeds

## Owner revision — 2026-11-02

- [x] T020 Regression tests first: light default, saved/system modes, failed/queued saves, contrast, narrow 2× text and auth themes
- [x] T021 Refine dark surfaces, borders, type and responsive search
- [x] T022 Recipe previews and adaptive mode selector; save failure feedback and serialized persistence
- [x] T023 Integrate current main, account lifecycle and account-scoped shopping UUID/outbox compatibility; keep demo isolated
- [x] T024 Format, scripts/check.sh, macOS build and rendered phone/wide visual QA

Validation: `scripts/check.sh` — clean analysis, 398 passing tests; `flutter build macos --debug` — succeeds. Six rendered previews with bundled text and icon fonts inspected: light/dark phone and wide layouts, 320 px at 2× text, and dark sign-in. Tests use only in-memory databases and fake backends.

- [x] T025 Native startup: test and recover v4 cache marked v3, preserving ids and outbox; checks, build and live launch

Native startup validation: regression first reproduced the duplicate-index exception; after the fix, all 399 tests and analysis pass, macOS debug build succeeds, and the live app opens the sign-in screen. Existing device cache was retained; a private local SQLite recovery snapshot was taken before reopening.


## UX refinement — 2026-11-02

- [x] T026 Remove timed startup/refresh delays; cover real loading and ready states.
- [x] T027 Shorten and cap motion; honour reduced motion during active feedback;
  pause offscreen message timers; remove fridge flicker.
- [x] T028 Commit shopping demo differences before one batch confirmation;
  serialize actions, add checked semantics and preserve idempotent behaviour.
- [x] T029 Add stable semantic status colours, clarify screen-on icon, simplify
  preview borders and make empty shopping/pantry states accurate and useful.
- [x] T030 Targeted regressions, full check.sh, macOS build and rendered visual QA.


UX validation: `scripts/check.sh` passes (clean analysis, 413 tests);
`flutter build macos --debug` succeeds. Eight rendered previews with synthetic
content and bundled fonts checked: shopping, dark pantry, wide shopping,
320 px shopping at 2× text, gallery normal/320 px at 2×, appearance light/dark.
Active reduced-motion regressions were reproduced before the fix and now pass;
refresh uses a controlled data-read gate and finishes without a minimum delay.
The 320 px / 2× navigation regression was reproduced and fixed; the active
tab name stays on one line with full text scaling.
No new dependencies, schema changes or production backend calls.


PR follow-up: original #12 is merged. The UX patch was reapplied without conflicts
on `fix/005-ux-refinements` from main `16cd918`, preserving the original branch.
On this base, `scripts/check.sh` passes with 471 tests and clean analysis;
`flutter build macos --debug` succeeds.
