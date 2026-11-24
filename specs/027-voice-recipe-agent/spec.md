# Specification: Voice-assisted recipe drafts

**ID**: 027-voice-recipe-agent | **Feature key**: VOICE
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Product lead**: Dev 4 | **Implementer**: Dev 2 (Ceviz) | **Proposed independent reviewer**: Dev 3

## Scope and source

Implements voice input in the new-recipe flow. The user dictates a recipe,
reviews the draft in the existing editor and explicitly saves it. Clarifications
appear as text and can be answered by speaking or typing. Speech synthesis,
recipe read-aloud and cooking mode are outside scope. This scope supersedes
the earlier platform-speech proposal in the [product design](../../docs/product-design.md).
Preserve inherited 010 quantity, snapshot, offline and account invariants.
Source IDs and phases retain their original traceability. The current Trello
assignment is Ceviz.

## Requirements and source traceability

- **FR-001**: Capture voice on demand and transcribe Serbian speech with Groq. Source D4-018, phase 4. [Trello](https://trello.com/c/1zNjMr4K)
- **FR-002**: Convert a transcript into validated recipe draft edits and optional text clarifications. Source D4-019, phase 4. [Trello](https://trello.com/c/5Ri5cwW3)

## Behavioral requirements

- **FR-101**: Flutter records only on user action and sends each completed audio clip to `POST /functions/v1/voice-transcribe`. The authenticated Edge Function validates the upload and quota before invoking Groq with a server-side key, then returns the transcript to Flutter.
- **FR-102**: Flutter sends the transcript and current draft as a separate text POST through `AIRouter` to `ai-gateway`. A text model returns allowlisted draft edits and optionally a clarification question. Flutter validates the response and updates the visible draft. Clarification questions appear as text. The user can answer by recording another turn or typing. Missing or ambiguous amounts remain unresolved until confirmed.
- **FR-103**: Review and explicit save use the existing recipe editor and catalog path. Cancellation, permission denial and interruption release the microphone. Late responses must not mutate a canceled or replaced draft. Model output may only affect the active draft through validated edits.
- **FR-104**: Verify Serbian transcription and microphone capture on Android, iOS and macOS. Provide typed input when recording or transcription is unavailable. If processing fails after transcription, allow retrying the existing text without another recording. Manual editing remains available when offline. Future Windows support follows 028.

## User scenarios and acceptance

- **US1 / SC-001**: A spoken ingredient edit updates the preview; cancel leaves the saved recipe unchanged.
- **US2 / SC-002**: Unknown command or instructions embedded in transcript cannot execute an unrelated action.
- **US3 / SC-003**: Denied microphone permission gives a text path and does not leave recording active.
- **US4 / SC-004**: After dictation, Flutter receives the Groq transcript before sending a separate text POST. The text model receives the transcript and draft, and the app renders the validated edits. If this POST fails, retry uses the retained text and makes no new transcription call.
- **US5 / SC-005**: “Dodaj brašno” produces a clarification such as “Koliko brašna ide?” as text. A spoken or typed reply updates the quantity. The recipe is persisted only after the user confirms the draft in the editor.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Audio and transcripts are transient user content. The audio goes to Groq via
the authenticated Edge Function. The recipe model receives text and draft data.
Do not log, persist or sync audio or raw transcripts. Clean up temporary audio
after transcription, failure or cancellation. Keep the current transcript
in memory only for the active draft turn and its retry, then discard it.
Persist and sync the confirmed recipe through the existing path. Validate
audio format, size and duration, and enforce authenticated quotas before
provider work. Record provider retention and processing location before rollout.

## Exact UI copy

“Govori”, “Zaustavi”, “Otkaži”, “Pregledaj recept”.
Example clarification: “Koliko brašna ide?”
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [014](../014-ai-response-contracts/spec.md), [015](../015-ai-server-gateway/spec.md), [018](../018-ingredient-catalog/spec.md)

- **Accepted direction (2026-11-22)**: Groq handles transcription through the
  audio Edge Function. Flutter receives the transcript and submits a separate
  request to the text model through the gateway. Clarifications are text-only.
- **Q1** (Dev 4 with independent review; Ceviz runs the [prototype](https://trello.com/c/qJ9r0D4w)):
  Confirm the Groq model against Serbian dictation, device recording format,
  size and duration caps, quotas, deadlines and provider retention controls.
  Finalize the typed request and response contracts and acceptance fixtures.
  **Proposed 2026-11-22 (Dev 2):** `whisper-large-v3` with a measure-only
  context prompt, 120 s / 3 MB AAC, text quota, 30 s deadline; measured on 17
  synthetic recordings in [research](research.md); typed contracts in the
  [voice agent contract](contracts/voice-agent-contract.md). Device recording
  checks on Android, iOS and macOS are still open.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
