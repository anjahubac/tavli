# Specification: Meal suitability, snacks and plan selection

**ID**: 019-meal-selection-rules | **Feature key**: MEAL-RULES
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 1 and Dev 3

## Scope and source

Implements the MEAL-RULES portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Annotate recipes with meal suitability and dish type**. Source D2-005; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Represent daily meals as a list including snacks**. Source D2-006; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Validate meal placement rules**. Source D2-007; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Include authorized tastes and preferences in plan requests**. Source D2-009; Dev 2; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Enforce allergen restrictions in plans**. Source D2-011; Dev 2; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Prefer favorite recipes in plans**. Source D2-012; Dev 2; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Select saved recipes locally before generating new ones**. Source D2-013; Dev 2; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Support breakfast, morning snack, lunch, afternoon snack and dinner without fixed three-field assumptions; include snacks in shopping/Home/intake.
- **FR-102**: Default lunch medium/hearty cooked/roast, dinner light/medium; at most one hearty meal daily, no same dish kind on consecutive days; household defaults editable.
- **FR-103**: Snacks are light without cooked dishes. Locked/cooked/imported meals are preserved by regeneration; show restriction conflicts rather than silently rewrite a locked meal.
- **FR-104**: Allergens constrain selection before approval; taste/favorite aggregation uses only the accepted personal-data contract.
- **FR-105**: Select suitable saved recipes locally first and use AI for gaps; validate final placement in app code, not just prompt wording.

## User scenarios and acceptance

- **US1 / SC-001**: Regeneration fills an open snack slot while preserving a locked imported lunch and existing servings.
- **US2 / SC-002**: An allergenic or misplaced suggestion cannot be silently approved; exhausted candidates return a visible incomplete draft.
- **US3 / SC-003**: Existing recipes without tags get a reviewed/backfillable unknown state, not arbitrary hardcoded suitability.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

List-based meal slots and closed suitability/intensity/kind metadata require coordinated cache/server migration and compatibility for saved three-meal plans. Authorized member aggregates come from 008.

## Exact UI copy carried forward

“Užina pre podne”, “Užina posle podne”, “Ponovo predloži”, “Proveri predlog”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [008](../008-household-members/spec.md), [014](../014-ai-response-contracts/spec.md)

- **Q1** (Dev 2 with reviewer): Finalize enums, existing-recipe backfill, household rule edit UI, repeat rules scope and favorites aggregation with 008.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
