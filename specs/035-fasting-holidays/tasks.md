# Tasks: Orthodox fasts and holidays

Status: planned, not completed. Lead: Dev 2; proposed reviewers: Dev 4 and
Dev 1 (choose a different human from the implementer). Paths and contracts are
in plan.md; finalize exact filenames and estimates before Ready.

- [ ] T001 Record Q1–Q8 decisions for each approved slice in spec.md. Agree the calendar API, chunk table and fixtures. For AI Q&A, deliver a reviewed amendment to the [015 gateway contract](../015-ai-server-gateway/contracts/ai-gateway-contract.md) covering `fasting_question` and Q5 accounting before T005. Owner Dev 2; reviewer Dev 4 with Dev 3 on the gateway contract; evidence: accepted decision/contract links.
- [ ] T002 [US1][US4] FR-001, phase 4: SPC-checked fixtures for Pascha, movable/fixed fasts, fast-free weeks, Cheesefare, Great Friday, the 12/13 November contrast and the Nativity fast across the year boundary. Owner Dev 2; reviewer Dev 1; depends on T001 calendar decisions.
- [ ] T003 [US4] FR-001, phase 4: orthodox calendar module in `lib/domain/`. Owner Dev 2; reviewer Dev 1; depends T002.
- [ ] T004 [US2] FR-002, phase 4: knowledge chunk migration (shared with 026), generator script and team-written explanations. Owner Dev 2; reviewer Dev 1; depends T003 and Q2.
- [ ] T005 [US2] FR-003, phase 4: implement the reviewed `fasting_question` contract. Test explicit years, cross-year occurrences, invalid references (including real dates for the wrong event), “ne znam”, user-key accounts, quota rejection before provider work and isolation from private cookbook chunks. Owner Dev 2; reviewer Dev 3; depends on the T001 gateway amendment, T004 and the 015 gateway.
- [ ] T006 [US1][US5] FR-007, phase 4: Home status card, question screen (phone) and side panel (desktop) per the canvas. Owner Dev 4; reviewer Dev 2; depends T003 (card) and T005 (answers).
- [ ] T007 [US3] FR-004, phase 4: recipe fasting label, AI fill and user correction. Owner Dev 2; reviewer Dev 1; depends T001 and the 019 labels.
- [ ] T008 [US3] FR-005, phase 4: “Pratim post” household setting and its screen after Q3/Q7. Owner Dev 3; reviewer Dev 2; depends T001.
- [ ] T009 [US3] FR-006, phase 4: plan generation and replacements respect effective fasting rules. Test the one-plan override with “Pratim post” off, water/fish strictness, and the policy for time-limited abstinence. Owner Dev 2; reviewer Dev 4; depends T003, T007, T008.
- [ ] T010 FR-008, phase 4: compute the recipe fasting label from catalog food categories, keeping user corrections. Owner Dev 1; reviewer Dev 2; depends T007 and 018.
- [ ] T011 Integrate evidence, record limits and update the flow map. Owner Dev 2; reviewer Dev 4; depends on applicable tasks.

Each Ready task records exact files, named reviewer, producer PR, remaining
days and risk. Done requires accepted behavior, real evidence and a merged PR.
