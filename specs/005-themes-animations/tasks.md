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

## Phase 8: Polish

- [x] T018 Update `docs/architecture.md` (theme + animations), `docs/roadmap.md`, `AGENTS.md` structure
- [x] T019 `scripts/check.sh` green; `flutter build macos --debug` succeeds
