# Tasks: Meal plans and linked shopping

**Input**: [spec](spec.md), [plan](plan.md), [research](research.md),
[data model](data-model.md), [contracts](contracts/app-interfaces.md),
[UX gates](contracts/ux.md).
**Status**: future implementation tasks; all are deliberately unchecked.
This documentation revision does not implement or validate the application.

**Tests**: mandatory test-first for domain/AI parsing and meaningful repository,
sync, migration, RLS and UI flows (constitution V). Write/observe the failing
test before its implementation. Use fake AI/backend, never hosted production.

## Phase 1 — Setup and UX validation

- [ ] T001 Bring 010 up to current main after 005 lands and record baseline/dependency review in `specs/010-plan-and-shopping/quickstart.md`; preserve existing auth, theme, wake lock and migration fixes, without stacking branches.
- [ ] T002 Build the connected synthetic-data prototype in `docs/prototypes/010-plan-shopping.html`, covering no-plan recipe shopping and monthly setup, preview, replace/lock, weekly shopping, pantry confirmation, purchase undo, cooking and all UX-005 states.
- [ ] T003 Evaluate the prototype with five first-time participants and record observations/corrections/retest in `specs/010-plan-and-shopping/ux-evaluation.md`, using `contracts/ux.md`; do not mark the UX gate passed without results.
- [ ] T004 Declare feature boundaries/providers and immutable interface skeletons following `lib/features/planning/`, `lib/domain/meal_plan.dart` and `lib/ai/meal_plan_ai.dart`; add no dependency without a plan justification.

## Phase 2 — Foundational data and domain rules

- [ ] T005 [P] Write failing civil-date, six-week/leap/DST, portion-scaling, compatible/unknown-unit and demand-identity tests in `test/domain/plan_calendar_test.dart` and `test/domain/shopping_demand_test.dart`.
- [ ] T006 Implement immutable plan/snapshot/calendar/quantity/source models in `lib/domain/meal_plan.dart`, `lib/domain/plan_calendar.dart`, `lib/domain/shopping_demand.dart` and `lib/domain/shopping_source.dart`, injecting clock and fixed quantity precision.
- [x] T007 [P] Write migration-preservation fixtures in `test/data/migration_test.dart` and two-account policy/grant/FK/tombstone tests in `supabase/tests/07_plan_shopping_test.sql` for new child tables and added fields.
- [x] T008 Add the next drift schema version/migration in `lib/data/database.dart`, regenerate `lib/data/database.g.dart`, and add a new `supabase/migrations/20261102120000_plan_and_shopping.sql` with columns, three child tables (sources/contributions/allocations), RLS/grants, constraints, indexes and deletion triggers; never edit applied migrations.
- [x] T009 Write registry/order/round-trip/retry/wipe/legacy tests in `test/sync/entities_test.dart`, `test/sync/uploader_test.dart`, `test/sync/downloader_test.dart`, `test/sync/legacy_mover_test.dart` and `test/account/account_service_test.dart`; extend synthetic fixtures only.
- [x] T010 Implement parent-first mappings and reverse cleanup in `lib/sync/entities.dart`, `lib/sync/legacy_mover.dart`, `lib/account/account_service.dart` and `test/helpers/fake_backend.dart`; preserve old ids/manual/bought lists and personal scope.

- [ ] T011 Write failing per-entry demand, capacity, duplicate-credit, manual/bought preservation and fixed-precision tests in `test/domain/shopping_demand_test.dart` and `test/domain/supply_allocation_test.dart`.
- [ ] T012 Write account-scoped canonical-week/month, delta/outbox, source and immutable purchase-provenance tests in `test/data/shopping_repository_test.dart` and `test/data/pantry_repository_test.dart`.
  Done for `test/data/shopping_repository_test.dart`; the pantry-receipt half waits for `lib/data/pantry_repository.dart` (T026).
- [ ] T013 Implement per-entry reconciliation and deterministic supply allocation in `lib/domain/shopping_demand.dart` and `lib/domain/supply_allocation.dart` without semantic ingredient guesses.
- [x] T014 Implement canonical-period read/write and source/contribution/allocation transactions in `lib/data/shopping_repository.dart`; keep bought/manual records stable and whole-month reads aggregate-only.

Shared reconciliation is foundational because plan approval and edits must
update existing shopping atomically; do not defer this core until purchase UI.

## Phase 3 — US1: generate and approve (P1)

**Independent test:** fake week/month generation, failure/resume, approve and reopen offline.

- [x] T015 [US1] Write failing strict-JSON, missing/duplicate slots, invalid ids/servings, batching/cancel/limits and resume tests in `test/ai/meal_plan_ai_test.dart`.
- [x] T016 [US1] Implement `lib/ai/meal_plan_ai.dart` and `lib/ai/meal_plan_prompts.dart` through AIRouter text, week outlines and bounded recipe-summary batches; keep drafts in-session.
- [x] T017 [US1] Write approval/discard/explicit-partial/stale-fingerprint/atomic-outbox tests in `test/data/meal_plan_repository_test.dart` with fake backend failure injection.
- [x] T018 [US1] Implement approval/read providers in `lib/data/meal_plan_repository.dart`, `lib/features/planning/planning_providers.dart` and `lib/providers.dart`, persisting approved data atomically and rejecting known stale drafts.
- [x] T019 [US1] Write first-plan/no-pantry, three-stage setup, retained-input/error/progress and review-before-save tests in `test/features/planning/plan_generation_test.dart` for phone and wide.
- [x] T020 [US1] Implement essentials setup and draft preview in `lib/features/planning/plan_setup_screen.dart` and `lib/features/planning/plan_preview_screen.dart`, with optional detail, cancel/retry and explicit partial save.

## Phase 4 — US2: calendar, snapshots and edits (P1)

**Independent test:** seeded plan, protected slots and library edits do not change accepted data.

- [x] T021 [US2] Write week/month/today/multiple-plan and 320 px selection tests in `test/features/planning/plan_calendar_test.dart`.
- [x] T022 [US2] Write protected/stale replace/regenerate, cooked-demand closure/stock review, servings, delete-source and snapshot-preservation tests in `test/data/meal_plan_repository_test.dart`.
- [x] T023 [US2] Implement reviewed entry edits and protected-slot filtering in `lib/data/meal_plan_repository.dart` and `lib/features/planning/planning_providers.dart`.
- [x] T024 [US2] Implement `lib/features/planning/plan_screen.dart`, `lib/features/planning/plan_calendar.dart` and `lib/features/planning/meal_entry_card.dart`, including readable phone/month and wide list–detail layouts.

## Phase 5 — US3: quantity-safe shopping (P1)

**Independent test:** repeated occurrences, six weeks and 300/100/200/400 fixture remain exact after retries.

- [ ] T025 [US3] Write purchase/undo, repeated receipt, linked-receipt review and no-double-credit tests in `test/data/shopping_repository_test.dart` and `test/data/pantry_repository_test.dart`.
- [ ] T026 [US3] Implement whole-row purchase/undo and one-time receipt in `lib/data/shopping_repository.dart` and `lib/data/pantry_repository.dart`, preserving the shared physical supply identity.
- [ ] T027 [US3] Write grouped list, two-tap access, quantity-review, source-meal detail, manual-add, bought/undo and offline feedback tests in `test/features/shopping/shopping_screen_test.dart`.
- [ ] T028 [US3] Implement `lib/features/shopping/shopping_screen.dart`, period/source/stock-review widgets and providers in `lib/features/shopping/`, with immediate reversible checkmarks and one-handed targets.

## Phase 6 — US4: standalone recipe shopping (P1)

**Independent test:** no plan, saved/generated recipe, repeat add, one changed home-stock choice and explicit later preparation.

- [ ] T029 [US4] Write source identity, zero-plan, unsaved preview/read-only, explicit shopping approval, repeat/delta and planned-context tests in `test/domain/shopping_source_test.dart` and `test/data/shopping_repository_test.dart`.
- [ ] T030 [US4] Extend `lib/domain/shopping_source.dart` and implement standalone snapshot/servings/preparation operations in `lib/data/shopping_repository.dart`, sharing supply accounting without hidden library/plan creation.
- [ ] T031 [US4] Write saved/search/import/generated ingredient-review, portions/home-stock and Plan/Recipe source-mode tests in `test/features/recipes/recipe_shopping_test.dart` and `test/features/shopping/shopping_screen_test.dart`.
- [ ] T032 [US4] Implement `lib/features/recipes/ingredient_review_sheet.dart` and explicit shopping actions in `lib/features/recipes/recipe_detail_screen.dart` and `lib/features/recipes/ai_preview.dart`; inspection stays read-only, separate shopping approval persists its source.
- [ ] T033 [US4] Implement source-mode/recipe-preparation selection in `lib/features/shopping/shopping_screen.dart` and providers, including planned-context versus separate-preparation choice and deliberate repeat.
- [ ] T034 [US4] Validate combined plan/recipe allocations, receipts, bought-source history, offline retry and no-plan navigation in `test/features/planning/planning_journey_test.dart` and `test/features/recipes/recipe_shopping_test.dart`; include the standalone path in `docs/prototypes/010-plan-shopping.html`.

## Phase 7 — US5: pantry and personal inputs (P2)

**Independent test:** edit pantry/preferences offline, confirm stock once and keep another user's data private.

- [ ] T035 [US5] Write failing taste parsing, expiry-window, unknown/stale quantity and no-automatic-consumption tests in `test/domain/taste_profile_test.dart` and `test/data/pantry_repository_test.dart`.
- [ ] T036 [US5] Write private taste/ratings, pantry correction, allocation invalidation and sync tests in `test/data/taste_repository_test.dart` and `supabase/tests/07_plan_shopping_test.sql`.
- [ ] T037 [US5] Implement basic inventory/confirmation and private typed taste access in `lib/data/pantry_repository.dart`, `lib/data/taste_repository.dart` and `lib/domain/taste_profile.dart`.
- [ ] T038 [US5] Write search/add/edit/expiry/use-in-plan and optional preference-form tests in `test/features/pantry/pantry_screen_test.dart` and `test/features/settings/taste_screen_test.dart`.
- [ ] T039 [US5] Implement `lib/features/pantry/pantry_screen.dart` and `lib/features/settings/taste_screen.dart` plus their providers, preserving first-plan use without required setup.

## Phase 8 — US6: recipes, cooking and feedback (P2)

**Independent test:** insert a recipe, cook approved steps offline and save optional private feedback.

- [ ] T040 [US6] Write add-to-plan, protected replacement, summary-step review, entry-based cooking after source deletion, explicit save-before-rating and rating privacy and wake-lock regression tests in `test/features/recipes/cooking_screen_test.dart` and `test/features/recipes/add_to_plan_test.dart`.
- [ ] T041 [US6] Implement scoped recipe-to-slot and optional feedback operations in `lib/data/meal_plan_repository.dart`, `lib/data/taste_repository.dart` and `lib/features/recipes/cooking_providers.dart`, preserving snapshot and history semantics.
- [ ] T042 [US6] Implement `lib/features/recipes/cooking_screen.dart` and add-to-plan integration in `lib/features/recipes/recipe_detail_screen.dart`; open original images honestly, preserve editing/history and existing wake-lock choice/release.

## Phase 9 — US7: shell, visual system and accessible journeys (P2)

**Independent test:** reach every task through tabs/avatar with old links, phone/wide and 2× text.

- [ ] T043 [US7] Write four-tab/Plan-home, avatar-every-tab, auth-return/deep-link and two-tap journey tests in `test/app/home_shell_test.dart`, `test/app/router_test.dart` and `test/features/planning/planning_journey_test.dart`.
- [ ] T044 [US7] Implement target shell/router/avatar in `lib/app/home_shell.dart`, `lib/app/router.dart` and `lib/features/settings/profile_screen.dart`; retain /shopping, /profile, recipes and all existing account/sync actions.
- [ ] T045 [US7] Write light/dark, 320/400/1200 px, text 2×, focus/semantics/contrast and reduced-motion checks in `test/app/theme_test.dart` and `test/features/planning/planning_accessibility_test.dart`.
- [ ] T046 [US7] Apply warm token-based hierarchy, readable controls and real loading/error/empty states in `lib/app/theme/app_theme.dart` and `lib/features/planning/`, `lib/features/shopping/`, `lib/features/pantry/`; remove artificial minimum waits in `lib/app/animations/intro_overlay.dart` while preserving startup/theme correctness.

## Phase 10 — Polish and release gates

- [ ] T047 Run the real app's five-person UX evaluation, fix blocking issues and record retest evidence in `specs/010-plan-and-shopping/ux-evaluation.md`; verify UX-001 through UX-006 and exact Serbian copy.
- [ ] T048 Benchmark 93 entries/1,000 contributions and add the reproducible local performance fixture in `test/domain/shopping_performance_test.dart`; record reference device/results in `specs/010-plan-and-shopping/quickstart.md`.
- [ ] T049 Exercise two-account offline/sync/migration/deletion and the complete month → week shopping → pantry → cooking journey in `test/features/planning/planning_journey_test.dart` and `supabase/tests/07_plan_shopping_test.sql`, including registry/wipe regressions.
- [ ] T050 Run formatter, `scripts/check.sh`, macOS debug build and local `supabase test db`; complete the phone/wide/text/motion matrix in `specs/010-plan-and-shopping/quickstart.md`, without production calls or real-key tests.
- [ ] T051 Update `docs/roadmap.md`, `docs/architecture.md`, `README.md` and `specs/010-plan-and-shopping/spec.md` to implemented only after every acceptance/UX gate passes; include generated code and small tested commits.

## Dependencies and incremental strategy

- T001–T003: prototype/research can run on documentation, but no 010 app
  implementation before 005 lands on main. Resolve blocking prototype UX first.
- T004 → T005/T007; tests precede T006/T008. T009 → T010 follows model/schema
  design. T011/T012 → T013/T014 builds shared reconciliation before T017/T018
  approval and T022/T023 edits. Source helpers and mappings are edited sequentially.
- Foundation → US1 → US2 → US3 is the planned-meal vertical slice. US4 is a
  parallel P1 slice for standalone shopping and must work with no plan. US5/US6 may be
  developed against seeded plans/stock; both are required before complete release.
- US7 routing/UX rules guide every story even though final shell integration is
  listed together. T043–T046 can be integrated earlier once foundations exist.
- T047–T051 close the feature. Weekly-only, a static prototype or passing unit
  tests alone are not enough to mark monthly shopping or UX complete.
- Parallel examples: T005 pure-domain fixtures and T007 migration/RLS fixtures
  use separate files; T038 pantry/settings widget fixtures and T040 recipe
  fixtures can be prepared independently after their contracts exist. Do not
  concurrently edit shared providers, database source or sync registry.

## Coverage map

| Requirement | Tasks |
| --- | --- |
| FR-001 | T002, T043, T044 |
| FR-002 | T005, T006, T021, T024, T049 |
| FR-003 | T005, T006, T017, T018, T022, T023 |
| FR-004 | T015, T016, T035, T036, T037, T049 |
| FR-005 | T015, T016, T019, T020 |
| FR-006 | T017, T018, T019, T020 |
| FR-007 | T022, T023, T024 |
| FR-008 | T021, T024, T043, T044 |
| FR-009 | T007, T008, T022, T023, T040, T041 |
| FR-010 | T011, T012, T013, T014, T027, T028 |
| FR-011 | T005, T006, T011, T013, T027, T028 |
| FR-012 | T007, T008, T012, T014, T027, T028 |
| FR-013 | T011, T012, T013, T014, T025, T026 |
| FR-014 | T011, T012, T014, T025, T026, T028 |
| FR-015 | T025, T026, T027, T028 |
| FR-016 | T025, T026, T036, T037 |
| FR-017 | T035, T036, T037, T038, T039 |
| FR-018 | T040, T041, T042 |
| FR-019 | T040, T041, T042, T049 |
| FR-020 | T035, T036, T037, T040, T041, T042 |
| FR-021 | T007, T008, T009, T010, T017, T012, T036, T049 |
| FR-022 | T040, T043, T044, T049, T050 |
| FR-023 | T002, T003, T045, T046, T047, T050 |
| FR-024 | T017, T019, T020, T027, T035, T038, T046, T049 |
| FR-025 | T035, T036, T037, T040, T041 |
| FR-026 | T002, T003, T019, T027, T043, T045, T046, T047 |
| FR-027 | T029, T030, T031, T032, T033, T034 |
| FR-028 | T011, T012, T025, T026, T029, T030, T034 |
| FR-029 | T029, T030, T031, T032, T033, T034 |
| SC-001 | T005, T006, T015, T021, T049 |
| SC-002 | T011, T012, T025, T026, T049 |
| SC-003 | T011, T013, T025, T026 |
| SC-004 | T022, T023, T040, T041 |
| SC-005 | T009, T010, T017, T012, T036, T049 |
| SC-006 | T002, T021, T027, T038, T040, T045, T046, T050 |
| SC-007 | T007, T008, T009, T036, T049 |
| SC-008 | T040, T043, T044, T049, T050 |
| SC-009 | T003, T047, T050 |
| SC-010 | T002, T019, T027, T043, T047 |
| SC-011 | T029, T030, T031, T032, T033, T034, T047 |

Operational setup/foundation T001/T004–T014 and release T047–T051 support
multiple stories and constitution gates; they are intentionally not marked as
separate product user stories. All implementation checkboxes remain open.
