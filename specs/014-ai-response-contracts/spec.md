# Specification: Strict AI recipe and plan contracts

**ID**: 014-ai-response-contracts | **Feature key**: AI-SCHEMA
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 2 | **Proposed independent reviewer**: Dev 1

## Scope and source

Implements the AI-SCHEMA portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Agree recipe and meal-plan AI contracts**. Source D2-001; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Validate AI responses strictly**. Source D2-002; Dev 2; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Repair invalid AI responses with bounded retries**. Source D2-010; Dev 2; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Each task defines required fields, bounds, nullability, units and closed meal enums; reject wrong shapes and invalid semantics with FormatException.
- **FR-102**: Validate portions, quantities, meal dates/slots and completeness; unknown ingredient mapping remains explicit rather than silently invented.
- **FR-103**: Keep one bounded repair/fallback policy in AIRouter; cancellation stops work and cannot save partial or stale results.
- **FR-104**: Error handling follows 012: no raw provider content or secret-bearing diagnostics.

## User scenarios and acceptance

- **US1 / SC-001**: Valid JSON with negative portions or unknown meal kinds fails validation without storing a recipe.
- **US2 / SC-002**: A malformed response is repaired within the bounded policy or gives a safe Serbian error; cancellation leaves saved data unchanged.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Untrusted AI output is a versioned draft. No persistent writes until schema/domain validation and user approval; preserve compatibility with saved recipe snapshots.

## Exact UI copy carried forward

“Proveri predlog”, “AI je vratio neispravan odgovor.”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [013](../013-testing-strategy/spec.md)

- **Q1** (Dev 2 with reviewer): Agree exact task schema versions, numeric/string bounds and allowed unknown fields before parser changes.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
