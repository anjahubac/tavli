# Specification: Calendar dates without time-zone drift

**ID**: 016-calendar-date-storage | **Feature key**: DATES
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 2

## Scope and source

Implements the DATES portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Migrate calendar-day columns to dates without time zones**. Source D1-002; Dev 1; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Migrate plan days and shopping period days with an explicit legacy interpretation, not device-zone-dependent conversion.
- **FR-102**: Preserve IDs, approved snapshots, week identity and pending outbox; define compatibility with older clients before release.
- **FR-103**: Do not silently remove legacy expiry columns or convert all timestamps; pantry expiry retirement is a separate data-preservation decision.

## User scenarios and acceptance

- **US1 / SC-001**: A saved day stays the same across UTC offsets, DST and app restart.
- **US2 / SC-002**: Upgrading a cache containing an unsent meal and a year-boundary weekly list preserves both day and source identity.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Calendar days use CivilDate/Postgres date; event timestamps remain UTC instants. New SQL and coordinated drift migration preserve old rows and queued payloads.

## Exact UI copy carried forward

No new UI copy in the initial technical slice.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [013](../013-testing-strategy/spec.md)

- **Q1** (Dev 1 with reviewer): Agree server/client cutover order and compatibility for old timestamp payloads; enumerate exact calendar columns and supported cache versions.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
