# Implementation plan: Catalog-based shopping and supply reconciliation

**Status**: catalog work remains a scoped proposal; the PR #49 correction slice
below records separate shopping UI work and does not complete this roadmap.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 1 / Dev 4
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `lib/data/shopping_repository.dart`
- `lib/domain/shopping_demand.dart`
- `lib/domain/supply_allocation.dart`
- `lib/features/shopping/`
- `lib/sync/entities.dart`
- `test/data/shopping_repository_test.dart`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

Preserve existing shopping sources/contributions/allocations, integer micros and receipt provenance. Catalog migration is additive with legacy unmapped fallback; refactor by responsibility without changing semantics.

Producer dependencies: [017](../017-kitchen-unit-conversion/spec.md), [018](../018-ingredient-catalog/spec.md)

The [shopping split baseline](split-evidence.md) records existing ownership,
test evidence and candidate boundaries for review. It is not approval of the
split or evidence that D1-004 is implemented.

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.

The proposed contract for Trello #25/#26 is
[shopping food identity and catalog entry](contracts/shopping-food-identity-contract.md).
It is intentionally not accepted yet; T001 remains open pending Dev 4 and the
listed schema/compatibility decisions.
If no schema change is needed, explicitly record that decision in the slice PR.

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
limits from open questions remain release gates. Follow the design canvas and
UI standard when applying the existing theme and motion components.

## PR #49 review corrections — 2026-11-19

Scope: D4-004 / FR-005 and FR-101. Anja owns the
slice; Uroš is the requested independent reviewer. No catalog producer contract
or schema change is needed for this presentation/state correction.

Affected paths: `lib/features/shopping/shopping_screen.dart`,
`shopping_providers.dart`, `shopping_list_view.dart` in the same directory, and
`lib/features/recipes/ingredient_review_sheet.dart`, with matching widget tests.
The unrelated global button theme change in `lib/app/theme/app_theme.dart` is
reverted to `dev`; no new theme contract is introduced.

`ShoppingView.mode` remains nullable while loading. Initialize it once from
successful plan and recipe-item snapshots; preserve it across stream updates and
navigation. Manual selection takes precedence and account changes reset the view.
This is account-session UI state, not a persisted setting; restart persistence
from SC-003 remains outside this correction. Retry invalidates the affected
local data providers; errors never become an empty shopping list or expose raw
exception text. Large text retains its scale, with vertical segments on narrow
screens. Action snackbars expire after five seconds normally, but remain
available with accessible navigation and offer a close button.

Security/privacy/abuse/credentials/files/deployment impact: N/A; no new endpoint,
logging, credential, file access or deployment change. Existing repositories,
account scope, outbox writes, quantities and identifiers remain unchanged. No
migration, dependency or generated output is required. Tests use synthetic local
data and fake backends; no hosted service is contacted. Human review and the
remaining canonical task acceptance are still required before delivery Done.
