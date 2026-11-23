# Specification: Household change signals and reconnect recovery

**ID**: 009-household-realtime | **Feature key**: REALTIME
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: implementation in review; release and device acceptance are pending.
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
- **FR-104**: A change to the user's own membership (removal, transfer, join) runs the existing membership check (`AuthController.restoreSession` → `AccountService.refreshMembership`), not only a pull. A pull cannot detect removal: RLS returns zero old-household rows without an error. The signal must come through a row the removed user can still read (for example their own account or profile row). Household tables stop delivering events once RLS denies access.
- **FR-105**: Realtime supplements, not replaces, the reactive check on denied writes (RLS `42501`, Storage `403` → `SyncEngine.onForbidden`). A signal can be missed while offline, in the background or during a reconnect.

### Known gap carried from the denied-write fix

An RLS-filtered `DELETE` by a removed member affects zero rows and returns no error. The uploader marks it sent, and no membership check starts. A removed member who only deletes is therefore detected at the next resume or start. Options: return deleted rows (`.select()`) and treat an empty result for a known row as a possible denial, or rely on the FR-104 signal. Decide together with Q1. The old household loses nothing, because the removed member no longer has access to it.

**Decision:** accepted as a known limitation of 009. It is not fixed here and relies on the FR-104 signal and the recovery paths above.

## User scenarios and acceptance

See the [Realtime acceptance fixtures](contracts/acceptance.md).

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

- **Q1** (Dev 3 and Dev 1, confirmed by Matija on 2026-11-23): use Postgres Changes on scoped revision tables, a 250 ms quiet window with a one-second cap, SDK reconnection, and a five-second local freshness target. See the [experiment](research.md) and [signal contract](contracts/signals.md).

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
