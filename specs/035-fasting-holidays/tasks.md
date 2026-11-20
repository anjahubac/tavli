# Tasks: Orthodox fasts and holidays

Status: planned, not completed. Lead: Dev 2; proposed reviewers: Dev 4 and
Dev 1 (choose a different human from the implementer). Paths and contracts are
in plan.md; finalize exact filenames and estimates before Ready.

- [ ] T001 Resolve Q1–Q7 in spec.md, agree the calendar API, chunk table and gateway request contract with fixtures. Owner Dev 2; reviewer Dev 4; evidence: accepted decision/contract links.
- [ ] T002 [US4] FR-001, phase 4: failing fixtures for Pascha, movable/fixed fasts, fast-free weeks and fasting levels, checked against the SPC calendar. Owner Dev 2; reviewer Dev 1; depends T001.
- [ ] T003 [US4] FR-001, phase 4: orthodox calendar module in `lib/domain/`. Owner Dev 2; reviewer Dev 1; depends T002.
- [ ] T004 [US2] FR-002, phase 4: knowledge chunk migration (shared with 026), generator script and team-written explanations. Owner Dev 2; reviewer Dev 1; depends T003 and Q2.
- [ ] T005 [US2] FR-003, phase 4: `fasting_question` in `ai-gateway` with retrieval, one model call and the date check; fake-AI tests for “ne znam”. Owner Dev 2; reviewer Dev 3; depends T004 and the 015 gateway.
- [ ] T006 [US1][US5] FR-007, phase 4: Home status card, question screen (phone) and side panel (desktop) per the canvas. Owner Dev 4; reviewer Dev 2; depends T003 (card) and T005 (answers).
- [ ] T007 [US3] FR-004, phase 4: recipe fasting label, AI fill and user correction. Owner Dev 2; reviewer Dev 1; depends T001 and the 019 labels.
- [ ] T008 [US3] FR-005, phase 4: “Pratim post” household setting and its screen after Q3/Q7. Owner Dev 3; reviewer Dev 2; depends T001.
- [ ] T009 [US3] FR-006, phase 4: plan generation and replacement respect fasting levels. Owner Dev 2; reviewer Dev 4; depends T003, T007, T008.
- [ ] T010 FR-008, phase 4: compute the recipe fasting label from catalog food categories, keeping user corrections. Owner Dev 1; reviewer Dev 2; depends T007 and 018.
- [ ] T011 Integrate evidence, record limits and update the flow map. Owner Dev 2; reviewer Dev 4; depends on applicable tasks.

Each Ready task records exact files, named reviewer, producer PR, remaining
days and risk. Done requires accepted behavior, real evidence and a merged PR.
