# Specification: External Tavli UI library preparation

**ID**: 031-external-ui-library | **Feature key**: UI-PACKAGE
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: all feature owners

## Scope and source

Implements the UI-PACKAGE portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Build the external UI package only after team agreement**. Source D4-024; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Apply current component standards now in existing folders; inventory genuinely reusable components and their theme/a11y contracts.
- **FR-102**: After team agreement, create external package with versioning, ownership, examples and compatibility policy; migrate one reversible consumer at a time.
- **FR-103**: Preserve light/dark, reduced motion, 2× text, focus/semantics and design tokens; do not redesign app or block features on package extraction.

## User scenarios and acceptance

- **US1 / SC-001**: A component renders consistently in app and package example without importing business repositories.
- **US2 / SC-002**: A package version change has compatibility evidence and consumer migration/rollback, not a mass unreviewed replacement.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

No business data or Supabase dependencies in reusable visual components. External repository creation and package extraction remain deferred until explicit team start.

## Exact UI copy carried forward

No new UI copy in the initial technical slice.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [021](../021-home-and-cooking/spec.md)

- **Q1** (Dev 4 with reviewer): Explicit start date/team approval, six linked library questions, real repository access, package distribution and version policy.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
