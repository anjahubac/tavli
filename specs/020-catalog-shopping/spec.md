# Specification: Catalog-based shopping and supply reconciliation

**ID**: 020-catalog-shopping | **Feature key**: SHOPPING-FOODS
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 4

## Scope and source

Implements the SHOPPING-FOODS portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Split shopping code by responsibility**. Source D1-004; Dev 1; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Aggregate shopping by ingredient identity**. Source D1-012; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Add manual shopping items from the catalog**. Source D1-013; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Account for pantry stock in shopping**. Source D1-014; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Fix the shopping-mode switch regression**. Source D4-004; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Fix the Po receptu → Po planu switch regression with reproduction evidence independently of the later catalog migration.
- **FR-102**: Group by canonical food and compatible unit; preserve original/unresolved text, approximate marker and unknown quantity instead of guessing.
- **FR-103**: Repeat Add changes only the delta; different recipes share supply once; bought/manual rows remain through reconciliation.
- **FR-104**: Known pantry stock reduces numeric demand; unknown presence stays visible with a check-quantity note, not full coverage.
- **FR-105**: Manual item input prefers catalog search but permits visibly unresolved text; month/weekly list boundaries and standalone preparation identity remain unchanged.

## User scenarios and acceptance

- **US1 / SC-001**: Add one missing item, unmark a second available item, add again: exactly one new need is created.
- **US2 / SC-002**: Demand 300 g, pantry 100 g, purchase 200 g, transfer: coverage is still 300 g; increasing demand to 400 g adds only 100 g.
- **US3 / SC-003**: Switching recipe/plan mode twice preserves selection and displays the correct list after navigation/restart.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Preserve existing shopping sources/contributions/allocations, integer micros and receipt provenance. Catalog migration is additive with legacy unmapped fallback; refactor by responsibility without changing semantics.

## Exact UI copy carried forward

“Po planu”, “Po receptu”, “Proveri količinu”, “Imaš u ostavi, proveri”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [017](../017-kitchen-unit-conversion/spec.md), [018](../018-ingredient-catalog/spec.md)

- **Q1** (Dev 1 with reviewer): Agree split boundaries before overlapping edits; capture the switch bug on the reported build/device; resolve legacy mapping and quantity display semantics.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
