# Tasks: Optional nutrition calculation and private diary

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 3;
proposed reviewers: Dev 1 and Dev 4 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 3; reviewer Dev 1 and Dev 4; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D1-011 / FR-001, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Add attributed nutrition reference values** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D1-011 / FR-001, phase 2: **Add attributed nutrition reference values** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D1-015 / FR-002, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Calculate calories and macros per recipe portion** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D1-015 / FR-002, phase 3: **Calculate calories and macros per recipe portion** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 [US1] D1-016 / FR-003, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Support meals without preparation steps** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T007 [US1] D1-016 / FR-003, phase 3: **Support meals without preparation steps** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T006; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T008 [US1] D2-014 / FR-004, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Display calculated calories in plans** at the tiers required by 013. Owner Dev 2; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T009 [US1] D2-014 / FR-004, phase 3: **Display calculated calories in plans** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 2; reviewer independent domain consumer; depends T008; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T010 [US1] D3-013 / FR-005, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Store private intake diary and targets** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T011 [US1] D3-013 / FR-005, phase 4: **Store private intake diary and targets** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T010; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T012 [US1] D3-014 / FR-006, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Record intake after cooked and ate confirmations** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T013 [US1] D3-014 / FR-006, phase 4: **Record intake after cooked and ate confirmations** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T012; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T014 [US1] D3-015 / FR-007, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide the nutrition diary screen** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T015 [US1] D3-015 / FR-007, phase 4: **Provide the nutrition diary screen** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T014; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T016 [US1] D3-016 / FR-008, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Support three optional nutrition-target modes** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T017 [US1] D3-016 / FR-008, phase 4: **Support three optional nutrition-target modes** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T016; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T018 [US1] D3-017 / FR-009, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide the calorie strip and source-method note** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T019 [US1] D3-017 / FR-009, phase 4: **Provide the calorie strip and source-method note** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T018; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T020 [US1] D4-022 / FR-010, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Integrate the optional calorie strip on Home** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T021 [US1] D4-022 / FR-010, phase 4: **Integrate the optional calorie strip on Home** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T020; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T022 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 3; reviewer Dev 1 and Dev 4; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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
