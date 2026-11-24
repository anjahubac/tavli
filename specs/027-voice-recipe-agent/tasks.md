# Tasks: Voice-assisted recipe drafts

Status: planned, not completed. Source IDs and phases are preserved. All source
tasks remain not_assessed until current code is checked. Product lead: Dev 4.
Implementer: Dev 2 (Ceviz). Proposed independent reviewer: Dev 3.
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 [Prototype](https://trello.com/c/qJ9r0D4w): measure Groq transcription on Serbian fixtures and verify recording on supported devices. Resolve Q1 with Dev 4 and independent review, including the typed contracts and acceptance fixtures.
- [ ] T002 [US3, US4] D4-018 / FR-001, phase 4: cover capture, permission denial, cancellation, invalid or over-quota uploads and the returned transcript at the tiers required by 013. Depends on T001 and the gateway auth/quota contract.
- [ ] T003 [US3, US4] D4-018 / FR-001, phase 4: implement Flutter capture and the authenticated Groq transcription endpoint. Return the transcript to Flutter and clean up transient audio. Depends on T002. [Trello](https://trello.com/c/1zNjMr4K)
- [ ] T004 [US1, US2, US4, US5] D4-019 / FR-002, phase 4: cover the second POST, typed edits, unknown commands, text clarification, retry without retranscription and explicit save at the tiers required by 013. Depends on T001 and the text gateway contract; use a fake transcript for isolated tests.
- [ ] T005 [US1, US2, US4, US5] D4-019 / FR-002, phase 4: send the transcript via `AIRouter`, validate and apply draft edits, render text questions, and connect review to the existing editor. Depends on T003 and T004. [Trello](https://trello.com/c/5Ri5cwW3)
- [ ] T006 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits with Dev 4 and the independent reviewer. Depends on T003 and T005. Link check commands, commit SHA, results and release decisions.

## Sequencing and effort

Do not treat this file's order as permission to run every task concurrently.
Dependencies are contracts plus phase/feature gates in the product plan. Tests
for future behavior land with that behavior; do not weaken current tests to make
it appear implemented. For research/infrastructure tasks use meaningful evidence
checks, not artificial Dart tests. Add task-specific subtasks when a source card
exceeds a 1–2-day reviewable slice. Cross-owner/shared-file changes need coordination.

Each Ready task records: exact files, named reviewer, producer PR, remaining days
(implementation + tests + review/integration), confidence and risk. Estimates are
not invented from ticket counts. Done requires accepted behavior, actual evidence
and merged PR; checkbox completion alone is not a release or an external approval.
