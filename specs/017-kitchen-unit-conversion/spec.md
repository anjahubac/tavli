# Specification: Kitchen measures and quantity conversion

**ID**: 017-kitchen-unit-conversion | **Feature key**: UNITS
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 1 | **Proposed independent reviewer**: Dev 2

## Scope and source

Implements the UNITS portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Aggregate kitchen measures in shopping**. Source D1-003; Dev 1; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Defaults: glass 200 ml, cup 250 ml, tablespoon 15 ml, teaspoon 5 ml; exact dimension conversions differ from approximate density/piece conversion.
- **FR-102**: Aggregate compatible quantities; approximate values carry ~ without an extra confirmation, unsupported conversion retains original amount and Proveri količinu.
- **FR-103**: Define household override precedence and rounding once at display boundary, preserving allocation and original text.

## User scenarios and acceptance

- **US1 / SC-001**: Two tablespoons plus one teaspoon resolve to 35 ml under defaults; a custom measure uses the agreed household override.
- **US2 / SC-002**: A cup of an ingredient with unknown density is not silently converted to grams or treated as zero.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Use integer micros and explicit conversion provenance. Phase-1 general measures precede catalog-specific density/piece data in 018.

## Exact UI copy carried forward

“Proveri količinu”, “~”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [013](../013-testing-strategy/spec.md)

- **Q1** (Dev 1 with reviewer): Finalize canonical unit aliases, precision/rounding and unknown/override precedence with catalog consumers.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
