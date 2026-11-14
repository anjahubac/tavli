# Specification: Windows application and release validation

**ID**: 028-windows-support | **Feature key**: WINDOWS
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements the WINDOWS portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Add and validate the Windows target**. Source D4-020; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Build Windows in CI**. Source D4-021; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Audit all plugins and OS integrations before target scaffolding: secure store, deep links/email auth, file picker, wake lock, SQLite and lifecycle.
- **FR-102**: Add reproducible build/CI, signing/distribution decision and real-machine smoke proof; unsupported capability gets an honest fallback.
- **FR-103**: Validate keyboard, resizing/scaling and native permission/dialog behavior with the existing responsive UI and security standards.

## User scenarios and acceptance

- **US1 / SC-001**: Clean Windows build installs/starts and signs in through the verified callback; offline restart preserves the correct account cache.
- **US2 / SC-002**: File pick/cancel, safe storage failure and wake-lock lifecycle behave correctly on a real Windows machine.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

New target must preserve secure session/key storage, account/environment isolation and file/outbox semantics. Windows is not currently supported merely because Flutter supports it.

## Exact UI copy carried forward

“Izaberi sliku”, “Funkcija nije dostupna na ovom uređaju.”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [012](../012-security-baseline/spec.md), [013](../013-testing-strategy/spec.md)

- **Q1** (Dev 4 with reviewer): Choose runner/hardware, signing/distribution route and plugin fallbacks; document any dependency changes before adding them.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
