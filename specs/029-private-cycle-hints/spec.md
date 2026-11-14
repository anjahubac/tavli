# Specification: Private opt-in cycle hints

**ID**: 029-private-cycle-hints | **Feature key**: CYCLE
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Dev 2 and Dev 4

## Scope and source

Implements the CYCLE portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Add approved cycle-related dietary hints**. Source D2-019; Dev 2; phase 5. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Store cycle consent and dates securely on device**. Source D3-019; Dev 3; phase 5. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Show a private local cycle indicator in the calendar**. Source D4-025; Dev 4; phase 5. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Off by default with explicit consent, no gender question; one-step deletion/disable and clear limits of estimates, no health claims.
- **FR-102**: Only the person generating the plan can apply her local hint; allergens, meal rules and locked meals take precedence.
- **FR-103**: Hints stop seven days after expected onset without confirmation until updated; local indicator never appears to another member/device.
- **FR-104**: No Apple Health/Health Connect integration in the first slice.

## User scenarios and acceptance

- **US1 / SC-001**: Two members share a plan but cannot see each other's dates/phase; network/sync fixtures contain no raw cycle data.
- **US2 / SC-002**: Stale input disables hints; deleting consent/dates removes indicator and future hints.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Consent and raw dates/phase are secure device-only, isolated by user; no drift sync, Supabase, analytics, export or raw AI fields. Optional generic dietary hint alone may enter the user's request.

## Exact UI copy carried forward

“Ritam ciklusa”, “Isključi”, “Obriši podatke”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [008](../008-household-members/spec.md), [019](../019-meal-selection-rules/spec.md), [012](../012-security-baseline/spec.md)

- **Q1** (Dev 3 with reviewer): Resolve six linked proposal questions, exact estimate/staleness semantics, consent copy and secure backup policy before implementation.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
