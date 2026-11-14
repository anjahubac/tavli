# Tasks: Home, adaptive navigation and cooking

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 4;
proposed reviewers: Dev 2 and Dev 1 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 4; reviewer Dev 2 and Dev 1; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D4-002 / FR-001, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Standardize components in the current repository** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D4-002 / FR-001, phase 1: **Standardize components in the current repository** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D4-003 / FR-002, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Introduce five-tab navigation with central Home** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D4-003 / FR-002, phase 1: **Introduce five-tab navigation with central Home** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 [US1] D4-005 / FR-003, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Use camera/gallery on phone and file selection on desktop** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T007 [US1] D4-005 / FR-003, phase 1: **Use camera/gallery on phone and file selection on desktop** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T006; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T008 [US1] D4-006 / FR-004, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide the monthly plan view** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T009 [US1] D4-006 / FR-004, phase 1: **Provide the monthly plan view** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T008; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T010 [US1] D4-007 / FR-005, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Keep mobile primary actions above navigation** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T011 [US1] D4-007 / FR-005, phase 1: **Keep mobile primary actions above navigation** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T010; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T012 [US1] D4-008 / FR-006, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Align meal cards and show accessible cooked status** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T013 [US1] D4-008 / FR-006, phase 1: **Align meal cards and show accessible cooked status** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T012; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T014 [US1] D4-009 / FR-007, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide the shared cooked/undo operation** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T015 [US1] D4-009 / FR-007, phase 2: **Provide the shared cooked/undo operation** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T014; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T016 [US1] D4-010 / FR-008, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Show today's meals on Home** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T017 [US1] D4-010 / FR-008, phase 2: **Show today's meals on Home** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T016; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T018 [US1] D4-011 / FR-009, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Show one prioritized notice on Home** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T019 [US1] D4-011 / FR-009, phase 2: **Show one prioritized notice on Home** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T018; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T020 [US1] D4-012 / FR-010, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide a readable cooking mode** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T021 [US1] D4-012 / FR-010, phase 2: **Provide a readable cooking mode** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T020; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T022 [US1] D4-013 / FR-011, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Add a recipe to a selected plan slot** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T023 [US1] D4-013 / FR-011, phase 2: **Add a recipe to a selected plan slot** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T022; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T024 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 4; reviewer Dev 2 and Dev 1; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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
