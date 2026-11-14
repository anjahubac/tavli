# Specification: Reviewed import of nutritionist plans

**ID**: 030-nutritionist-plan-import | **Feature key**: PLAN-IMPORT
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 1 and Dev 3

## Scope and source

Implements the PLAN-IMPORT portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Map imported meal-plan items to ingredients**. Source D1-020; Dev 1; phase 6. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Import and review a plan from image or text**. Source D2-020; Dev 2; phase 6. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Import PDF plans with alternatives and weekly repetition**. Source D2-021; Dev 2; phase 6. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Connect imported plans to diary and allergen checks**. Source D3-020; Dev 3; phase 6. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Capture and crop a meal-plan image for import**. Source D4-026; Dev 4; phase 6. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: First image/text capture, crop and strict extraction; review uncertain Proveri items, choose start date, then approve into calendar.
- **FR-102**: Preserve exact grams and original text; imported meals are locked against regeneration/rule rewriting and may have no preparation steps.
- **FR-103**: Later slice adds PDF, meal alternatives and weekly repetition without inventing missing meals/quantities.
- **FR-104**: Link allergen review and optional manual nutrition target only with explicit consent; AI does not invent nutrition values.
- **FR-105**: Word/Excel/share-sheet entry remain later extensions, not a dependency for the image/text slice.

## User scenarios and acceptance

- **US1 / SC-001**: A recipe-like meal with exact grams and no steps imports after review and works in shopping; regeneration leaves it unchanged.
- **US2 / SC-002**: An uncertain ingredient stays flagged; cancel persists neither partial plan nor original upload.
- **US3 / SC-003**: An imported target is offered for explicit use, never silently replaces a private goal.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Temporary original image/document is not retained; reviewed original ingredient text and exact quantities persist in approved snapshots. Import uses catalog mapping and explicit target/intake consent.

## Exact UI copy carried forward

“Uvezi plan”, “Proveri”, “Od kog datuma?”, “Sačuvaj plan”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [018](../018-ingredient-catalog/spec.md), [019](../019-meal-selection-rules/spec.md), [023](../023-optional-nutrition/spec.md)

- **Q1** (Dev 2 with reviewer): Resolve ten linked questions, transient/provider retention, conflict/alternative UX, PDF parser limits and cropping before dependent work.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
