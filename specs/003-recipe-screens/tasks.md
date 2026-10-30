# Tasks: Recipe screens

**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/recipe-repository.md](contracts/recipe-repository.md)
**Tests**: required (constitution V) — write each test task before its implementation task and see it fail.

Format: `[ID] [P?] [Story] Description` — `[P]` = can run in parallel (different files).

## Phase 1: Setup

- [ ] T001 Add `image` dependency (justified in plan.md) to `pubspec.yaml`

## Phase 2: Foundational (blocks all stories)

- [ ] T002 [P] Test: quantity formatting with decimal comma, grouping by store category in store order, diacritics-insensitive search, date/time format in `test/domain/recipe_format_test.dart`
- [ ] T003 [P] Implement `lib/domain/recipe_format.dart`
- [ ] T004 [P] Test: `Recipe.toJson`/`fromJson` round trip, `copyWith`, `newRecipeId` uniqueness in `test/domain/recipe_test.dart`
- [ ] T005 Implement `copyWith`, `toJson`/`fromJson`, `newRecipeId` in `lib/domain/recipe.dart`; `RecipeVersion` + `ChangeKind` in `lib/domain/recipe_version.dart`; `RecipeAI` uses `newRecipeId`
- [ ] T006 Test: migration v2 → v3 keeps version rows and adds columns in `test/data/migration_test.dart`
- [ ] T007 Add `changeKind`, `changedBy` to `RecipeVersions`, `schemaVersion` 3 + migration in `lib/data/database.dart`; regenerate `database.g.dart`
- [ ] T008 [P] Test: downscale to ≤ 1600 px JPEG, small images keep size, garbage → `FormatException` in `test/data/photo_resize_test.dart`
- [ ] T009 [P] Implement `lib/data/photo_resize.dart` and `lib/data/recipe_photo_store.dart` (+ test of save/file/delete with a temp dir)
- [ ] T010 Test: create/watchAll order, update keeps previous version with kind/instruction/model, prune to 30, undoLast, restore keeps current, delete removes versions/photo in `test/data/recipe_repository_test.dart`
- [ ] T011 Implement `lib/data/recipe_repository.dart`
- [ ] T012 Providers (repository, recipe streams, versions, photo store, photo picker) in `lib/features/recipes/recipe_providers.dart`; `PhotoPicker` in `lib/features/recipes/photo_picker.dart`; test helper `test/helpers/test_app.dart`

## Phase 3: User Story 1 — browse and read (P1)

- [ ] T013 [US1] Widget tests: empty state, newest first, search incl. "šar"/no match, detail grouping and footer, phone vs wide split in `test/features/recipes/recipes_screen_test.dart`
- [ ] T014 [US1] `recipe_view.dart`, `recipe_photo.dart`, `recipes_screen.dart`, `recipe_detail_screen.dart`; routes in `lib/app/router.dart`; update `test/app/home_shell_test.dart` to use an in-memory DB

## Phase 4: User Story 2 + 3 — add with AI (P1)

- [ ] T015 [US2] Widget tests: from name → preview → Sačuvaj stores and opens; Odbaci stores nothing; AI error shows Serbian text and keeps input; empty name disables button in `test/features/recipes/from_name_screen_test.dart`
- [ ] T016 [US2] `add_recipe_sheet.dart`, `ai_preview.dart`, `from_name_screen.dart`
- [ ] T017 [US3] Widget tests: picked photo → preview → Sačuvaj stores recipe with photo; not-a-recipe message; cancel does nothing; no camera → only gallery in `test/features/recipes/from_photo_screen_test.dart`
- [ ] T018 [US3] `from_photo_screen.dart`; iOS/macOS photo permissions checked

## Phase 5: User Story 4 — chat edits with undo (P2)

- [ ] T019 [US4] Widget tests: request → proposal → Prihvati updates recipe and history; Odbaci leaves it; undo restores; restore from versions sheet; AI error keeps text in `test/features/recipes/recipe_chat_screen_test.dart`
- [ ] T020 [US4] `recipe_chat_screen.dart`, `versions_sheet.dart`; undo/versions in detail menu

## Phase 6: User Story 5 — manual add/edit, delete (P2)

- [ ] T021 [US5] Widget tests: validation messages; manual create; edit keeps "Ručna izmena" version; leaving with unsaved changes asks "Odbaciti izmene?"; delete with confirmation in `test/features/recipes/recipe_form_screen_test.dart`
- [ ] T022 [US5] `recipe_form_screen.dart` (ingredient dialog, unsaved-changes prompt); delete action in detail

## Phase 7: Polish

- [ ] T023 [P] Update `docs/architecture.md`, `docs/roadmap.md`, `AGENTS.md` structure
- [ ] T024 `scripts/check.sh` passes; `flutter build macos --debug` succeeds; spec status → Implemented

## Dependencies

T001 → T008/T009. T002 → T003. T004 → T005. T006 → T007. T005, T007, T009 → T010 → T011 → T012.
T012 → T013 → T014 → (T015 → T016 → T017 → T018), (T019 → T020), (T021 → T022). All → T023, T024.

## Analysis (/speckit-analyze, 2026-10-30)

| FR | Tasks |
|---|---|
| FR-001 list newest first | T010, T013, T014 |
| FR-002 diacritics-insensitive search | T002, T003, T013 |
| FR-003 detail content | T013, T014 |
| FR-004 decimal comma | T002, T003 |
| FR-005 from dish name | T015, T016 |
| FR-006 from photo | T017, T018 |
| FR-007 photo downscaled + stored | T008, T009, T017 |
| FR-008 preview before save | T015, T017 |
| FR-009 manual add/edit | T021, T022 |
| FR-010 chat proposals | T019, T020 |
| FR-011 versions with kind/request/model | T006, T007, T010, T019, T021 |
| FR-012 undo + restore | T010, T019 |
| FR-013 30 versions | T010 |
| FR-014 delete with versions + photo | T010, T021 |
| FR-015 offline | T010–T022 (all non-AI tests run with no network adapter) |
| FR-016 AI errors in Serbian, input kept | T015, T019 |
| FR-017 list–detail on wide | T013 |

Findings: one coverage gap (US5 scenario 4, unsaved-changes prompt) fixed by
extending T021. No constitution conflicts (one new dependency, justified;
schema bump has migration + test). Terminology consistent: "version" always
means the state *before* a change; ChangeKind labels match the spec copy.
