# Specification: Shared ingredient catalog and matching

**ID**: 018-ingredient-catalog | **Feature key**: CATALOG
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 2 and Dev 3

## Scope and source

Implements the CATALOG portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Agree the ingredient model**. Source D1-001; Dev 1; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Create ingredient catalog tables**. Source D1-005; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Review and seed 300–400 ingredients**. Source D1-006; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Resolve ingredient names through the shared matcher**. Source D1-007; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Map existing recipe ingredients to the catalog**. Source D1-008; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Provide unresolved-ingredient review UI**. Source D1-009; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Support ingredient-specific units and conversions**. Source D1-010; Dev 1; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-008**: Deliver **Generate catalog-ready ingredient data**. Source D2-008; Dev 2; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Review 300–400 initial foods, categories, base units, aliases and conversion metadata before promotion; AI-generated seed data is not automatically trusted.
- **FR-102**: Aliases identify the same food, not substitutes. Yogurt fat variants can share identity under reviewed rules; flour T-400 and T-500 remain distinct.
- **FR-103**: One matcher serves recipes, plans, books, voice and import: alias/normalization then bounded AI-assisted proposal; uncertain mappings stay unresolved.
- **FR-104**: Backfill existing recipes idempotently without rewriting original text; unresolved entries still work by name and offer choose-existing/create-household-food UI.
- **FR-105**: Store density, piece weight, typical packaging and source/version provenance where known; apply scoped alias uniqueness and household overrides.

## User scenarios and acceptance

- **US1 / SC-001**: A repeated backfill preserves original ingredient wording and does not duplicate aliases or household foods.
- **US2 / SC-002**: A similar but different food never becomes an exact alias; low-confidence input remains visible and usable.
- **US3 / SC-003**: One household cannot edit the shared catalog or another household's custom food.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Proposed foods/aliases/units/household overrides; immutable UUID and readable slug. Shared reviewed catalog read-only to clients; household additions scoped by RLS. Recipe ingredients remain embedded with optional food_id and original text.

## Exact UI copy carried forward

“Poveži namirnicu”, “Nova namirnica”, “Proveri”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [017](../017-kitchen-unit-conversion/spec.md)

- **Q1** (Dev 1 with reviewer): Accept exact schema/alias uniqueness scope, matching confidence/review path and licensed seed provenance; coordinate version numbers at integration.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
