# Specification: Voice-assisted recipe drafts

**ID**: 027-voice-recipe-agent | **Feature key**: VOICE
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 4 | **Proposed independent reviewer**: Dev 2 and Dev 3

## Scope and source

Implements the VOICE portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Capture voice and transcribe speech**. Source D4-018; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Apply allowlisted voice draft commands and speak responses**. Source D4-019; Dev 4; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Press-to-talk captures speech, transcribes and supports a conversation that asks clarifying questions and answers through text/speech.
- **FR-102**: Only validated allowlisted draft commands may run; no arbitrary code, URLs, database writes or silent recipe save.
- **FR-103**: Review/save uses the existing recipe/catalog path; cancel/permission denial/interrupt releases microphone and ignores stale responses.
- **FR-104**: Verify Serbian speech quality/availability on each supported target and expose text fallback; future Windows follows 028.

## User scenarios and acceptance

- **US1 / SC-001**: A spoken ingredient edit updates the preview; cancel leaves the saved recipe unchanged.
- **US2 / SC-002**: Unknown command or instructions embedded in transcript cannot execute an unrelated action.
- **US3 / SC-003**: Denied microphone permission gives a text path and does not leave recording active.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Transient audio/transcript with explicit retention; speech actions update a draft only. Microphone permission and recording lifecycle are platform-managed; no hidden recording.

## Exact UI copy carried forward

“Govori”, “Zaustavi”, “Otkaži”, “Pregledaj recept”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [014](../014-ai-response-contracts/spec.md), [015](../015-ai-server-gateway/spec.md), [018](../018-ingredient-catalog/spec.md)

- **Q1** (Dev 4 with reviewer): Choose STT/TTS transport and retention/budgets; device Serbian voices require real-platform proof before promising support.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
