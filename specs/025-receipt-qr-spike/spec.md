# Specification: Receipt QR feasibility and safe import decision

**ID**: 025-receipt-qr-spike | **Feature key**: RECEIPT-QR
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements the RECEIPT-QR portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Spike: inspect receipt QR data**. Source D1-019; Dev 1; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Determine which receipt data is actually accessible, permitted and useful for catalog/price mapping; document limits and reproducible sample evidence.
- **FR-102**: Do not follow arbitrary QR destinations; accept only reviewed formats/endpoints with bounded fetch/parse and no credential forwarding.
- **FR-103**: Finish with go/narrow/no-go decision and estimated scope. A failed spike is a valid result and does not require a shipped scanner.

## User scenarios and acceptance

- **US1 / SC-001**: An unsupported or malicious QR is rejected without fetching an arbitrary URL.
- **US2 / SC-002**: A permitted synthetic receipt demonstrates exactly which quantities/prices can be mapped and what requires review.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Time-boxed research first. Synthetic/explicitly permitted samples only; never upload personal receipts or arbitrary QR URLs without an accepted retention/network contract.

## Exact UI copy carried forward

“Račun nije podržan.”, “Proveri stavke”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [018](../018-ingredient-catalog/spec.md)

- **Q1** (Dev 1 with reviewer): Agree spike time box, permitted source access, retention and go/no-go criterion before implementation.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
