# Implementation plan: Home, adaptive navigation and cooking

**Status**: five-tab shell, local UI library, cooked/undo operation, Home meals
and cooking mode are merged into dev. The notice slice is in implementation.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 4 / Dev 2 and Dev 1
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `lib/app/router.dart`
- `lib/app/home_shell.dart`
- `lib/app/tab_app_bar.dart`
- `lib/app/theme_controller.dart`
- `packages/tavli_ui/` (shared theme, components and gallery)
- `lib/features/planning/`
- `lib/features/recipes/`
- `lib/features/home/` (approved meals and prioritized notices)

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

Home is a projection of approved plan data, not another store. Shared cooked/undo operation stays in existing domain/repository boundaries; pantry and intake extend its versioned contract in 022/023.

Cooked/undo operation: [cooked meal contract](contracts/cooked-meal-contract.md)
(accepted by Dev 4, 2026-11-19). Proposed new file `lib/data/cooking_repository.dart`.

Producer dependencies: Existing baseline; no new producer feature required for the first slice.

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Priority delivery

1. **Phase 1, narrow navigation** (FR-101, SC-003/004). Dev 4 coordinates
   `lib/app/home_shell.dart`, `lib/app/router.dart`, `lib/app/tab_app_bar.dart`
   and `packages/tavli_ui/`. Resolve how the gallery's 220 dp sidebar and
   capped bottom labels fit the app's breakpoint and text requirements.
   Verify the app shell at both width boundaries and while resizing between
   layouts before replacing it. Keep the existing routes and state contracts.
2. **Phase 2, “Kuvaj” → “Skuvano” → “Poništi”** (FR-102/104/105/107/108,
   SC-001/005/007). Use an approved plan with saved steps and the merged
   cooked-operation contract. Dev 4 coordinates Home, recipe/cooking and
   Plan UI with Dev 2, shopping and pantry effects with Dev 1, and the
   separate personal-intake integration with Dev 3. Verify known and unknown
   stock, an intervening manual count, offline replay and visible undo.
   Complete the consumer checks in 020/022 as their dependencies land.
3. **Home notice, first slice** (FR-009, T018/T019, Trello #84). Anja (Dev 4)
   coordinates `lib/features/home/home_{screen,today,notice}.dart`, Home tests
   and the shared notice link's 48×48 target in
   `packages/tavli_ui/lib/src/content/tavli_notice.dart`.
   Dev 1 coordinates and reviews the read-only query in
   `lib/data/shopping_items.dart`. It reads the existing household-scoped
   contribution-to-open-item links, which the shopping reconciler assigns
   only to uncovered demand. No change to allocation or reconciliation.
   Verify priority, purchase/undo, and exclusion of later meals on synthetic
   offline fixtures. Check phone, wide, 2× text and reduced motion. Allergen
   warnings follow the reviewed member and catalog producers
   ([PR #96](https://github.com/anjahubac/tavli/pull/96),
   [Trello #63](https://trello.com/c/LvMLi58T)).

The notice uses existing scoped cache data. No schema, credentials, files,
abuse surface, external service or deployment changes.

The navigation and UI consumer slices use existing accounts, records and
repository interfaces. Privacy remains account or household scoped, with
personal intake owned by 023. Abuse, credentials, file access and deployment
changes are N/A for these UI slices. Use the producer's 012/013 evidence for
schema and sync changes.

## Delivery slices

1. Resolve only blocking decisions; map each source requirement to existing code,
   identify work already present and record remaining effort. Never redo completed
   behavior simply because a source ticket is unassessed.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in developers' existing
   checkouts, with one active writer per checkout; no automatic extra worktrees.
3. Implement one source task vertically through affected layers with test-first
   logic/parsing and ownership review. Keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | Any AI through AIRouter and validated task contract; N/A documented if none |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | Phone/wide/text/motion/keyboard proof for UI; N/A for technical-only slice |
| VII | Reviewable task slices; generated files via generator only |
| VIII | This canonical spec, owned dev-based branch/task IDs, no stacking |
| IX | Existing paths/interfaces; justify dependencies and migration decisions |
| X | Named human reviewer, producer/consumer contract and schema coordinator |

These are design obligations, not executed pass results. Any violation blocks Ready
until resolved under governance. No dependency is added by this documentation;
implementer records each proposed package/service with a reason before adoption.

## Verification, rollout and risks

Use [testing 013](../013-testing-strategy/spec.md), its journey matrix, and
[security 012](../012-security-baseline/spec.md). Tests must prove the scenarios
in spec.md and source task outcomes using synthetic data/fake AI. Default Flutter
tests do not contact a network; explicit guarded integration uses local services.
No speculative hosted deployment or publication. Record old-client/snapshot
compatibility, pending-outbox migration, failure/undo and forward recovery for
state changes. No destructive reset as a migration. Platform/source/legal/retention
limits from open questions remain release gates. UI follows the design canvas and the
UI standard; do not invent layouts or move components into the package incidentally.

## Add to plan design — 2026-11-22

Owner: Dev 4. Design approved by Anja on 2026-11-22 in the
[interactive draft](https://claude.ai/artifact/TEDBb8qsWdduLYfHAmy4yN); the
recipe screen is not on the design canvas yet, so the draft follows the
canvas style (Plan week strip, list groups, button heights). Refines FR-011,
FR-105 and FR-109. Trello [#86](https://trello.com/c/PCRHieJG).

- **Files**: `lib/features/recipes/add_to_plan_sheet.dart` (new: sheet/dialog,
  replace confirmation, message), `lib/features/recipes/recipe_detail_screen.dart`
  (third button), `lib/data/meal_plan_repository.dart` (`addRecipe`,
  `mealsIn`, `freeWeekAround`, `SlotTakenException`). Tests:
  `test/data/add_recipe_to_plan_test.dart`,
  `test/features/recipes/add_to_plan_test.dart`.
- **Target plan**: the newest plan containing the day, the same rule Home
  uses. Without one, a new plan covers the free, non-past days of that
  Monday–Sunday week, so plans never overlap. A missing meal type is added
  to the plan's meal types so Plan shows the row.
- **Replacement**: an occupied slot is replaced only with explicit
  confirmation; the repository re-checks inside the transaction and throws
  `SlotTakenException` if another device filled the slot meanwhile, and the
  UI asks again. Cooked, locked and past meals are never changed. Replacement
  keeps the entry id and takes the chosen servings.
- **Servings**: default is the recipe's servings, adjustable 1–20 (decision
  2026-11-22).
- **Recipe buttons**: one row when all three labels fit on one line; else
  “Kuvaj” and “Dodaj u plan” (without its icon) in a row with “Proveri
  sastojke” below; else one button per row. Labels never wrap, so heights
  stay equal.
- **Follow-up**: a third choice “Dodaj uz to” when a meal can hold more than
  one dish (decision 2026-11-22, not in this slice).
- **Data/security**: no schema change, no new dependency, no server change.
  Writes go through the existing outbox in one transaction with the shopping
  reconciliation; household scope as in `MealPlanRepository`. Privacy,
  abuse, credentials, files and deployment: N/A.
