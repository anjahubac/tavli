# Specification: Household change signals and reconnect recovery

**ID**: 009-household-realtime | **Feature key**: REALTIME
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Dev 1

## Scope and source

Implements the REALTIME portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Signal household changes in realtime**. Source D3-012; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: A remote change schedules the existing pull path; no direct realtime row writes from widgets.
- **FR-102**: Coalesce bursts and reconnect using cursors; duplicate/out-of-order signals must not lose pending local writes or resurrect deletions.
- **FR-103**: Subscription lifecycle follows account and membership; permission failures surface safely and fall back to existing resume/pull behavior.

## User scenarios and acceptance

- **US1 / SC-001**: Two local clients converge after one edits and the other reconnects, without duplicate rows.
- **US2 / SC-002**: After sign-out or member removal, old-channel events cannot change current-account UI/cache.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Realtime signals are authorized household invalidations. Drift remains the UI source; account/membership changes dispose subscriptions and reject old-scope writes.

## Exact UI copy carried forward

“Sinhronizacija”, “Čeka slanje”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [008](../008-household-members/spec.md)

- **Q1** (Dev 3 with reviewer): Select channel/publication policy, debounce/backoff budget and reconnect freshness target after a local load experiment.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
