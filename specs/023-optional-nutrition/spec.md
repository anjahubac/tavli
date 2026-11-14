# Specification: Optional nutrition calculation and private diary

**ID**: 023-optional-nutrition | **Feature key**: NUTRITION
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Dev 1 and Dev 4

## Scope and source

Implements the NUTRITION portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Add attributed nutrition reference values**. Source D1-011; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Calculate calories and macros per recipe portion**. Source D1-015; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Support meals without preparation steps**. Source D1-016; Dev 1; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Display calculated calories in plans**. Source D2-014; Dev 2; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Store private intake diary and targets**. Source D3-013; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Record intake after cooked and ate confirmations**. Source D3-014; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Provide the nutrition diary screen**. Source D3-015; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-008**: Deliver **Support three optional nutrition-target modes**. Source D3-016; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-009**: Deliver **Provide the calorie strip and source-method note**. Source D3-017; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-010**: Deliver **Integrate the optional calorie strip on Home**. Source D4-022; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Tracking is off by default, no sixth tab; use sourced values per 100 g and coverage/method, never AI-invented nutrient numbers.
- **FR-102**: Calculate portions using known convertible mass, marking incomplete coverage; unknown values are not zero. Meals without steps still work in shopping/intake.
- **FR-103**: Goals are Samo pratim by default, Ručno or optional Kalkulator; any suggested target is explicitly applied/edited, never forced.
- **FR-104**: When tracking is on, Skuvano records an editable portion for the actor; other people explicitly confirm Jela sam. Operation identity prevents duplicate intake; undo/correction supported.
- **FR-105**: Provide day/week diary, manual entry, optional plan calories/hide action and a Dev 3 calorie strip consumed by Home; show Izvori i metoda.

## User scenarios and acceptance

- **US1 / SC-001**: Seven mapped ingredients out of eight show partial coverage; the unknown ingredient is not counted as zero.
- **US2 / SC-002**: Cooking as one member never adds intake to another; replay/undo does not duplicate portions.
- **US3 / SC-003**: Turning tracking off hides calorie UI and stops new automatic intake according to the agreed retention policy.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Attributed nutrition values on reference foods are separate from owner-only intake/targets. Dev 1 calculation, Dev 3 diary/component, Dev 2 plan and Dev 4 Home consumers. No household-wide diary access.

## Exact UI copy carried forward

“Ishrana”, “Samo pratim”, “Ručno”, “Kalkulator”, “Izvori i metoda”, “Sakrij kalorije”, “Jela sam”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [008](../008-household-members/spec.md), [018](../018-ingredient-catalog/spec.md), [021](../021-home-and-cooking/spec.md)

- **Q1** (Dev 3 with reviewer): Resolve the seven linked tracker questions, source licensing/versioning, opt-out retention, rounding and optional calculator review before dependent work.
- **Q2** (Dev 3 with reviewer): Agree actor intake/correction and imported manual target consent; private sensitive cache protection is gated by 012.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
