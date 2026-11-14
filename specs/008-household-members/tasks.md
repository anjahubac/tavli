# Tasks: Household, member preferences and personal choices

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 3;
proposed reviewers: Dev 1 and Dev 2 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 3; reviewer Dev 1 and Dev 2; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D3-001 / FR-001, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Agree the member-input contract for planning** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D3-001 / FR-001, phase 1: **Agree the member-input contract for planning** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D3-002 / FR-002, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Complete sign-in refinements** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D3-002 / FR-002, phase 1: **Complete sign-in refinements** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 [US1] D3-004 / FR-003, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide taste and preference settings** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T007 [US1] D3-004 / FR-003, phase 1: **Provide taste and preference settings** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T006; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T008 [US1] D3-005 / FR-004, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Create invitation data and access rules** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T009 [US1] D3-005 / FR-004, phase 2: **Create invitation data and access rules** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T008; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T010 [US1] D3-006 / FR-005, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide household invitation UI** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T011 [US1] D3-006 / FR-005, phase 2: **Provide household invitation UI** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T010; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T012 [US1] D3-007 / FR-006, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Join a household with confirmation** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T013 [US1] D3-007 / FR-006, phase 2: **Join a household with confirmation** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T012; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T014 [US1] D3-008 / FR-007, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Manage household members and roles** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T015 [US1] D3-008 / FR-007, phase 2: **Manage household members and roles** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T014; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T016 [US1] D3-009 / FR-008, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Choose structured allergens per member** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T017 [US1] D3-009 / FR-008, phase 3: **Choose structured allergens per member** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T016; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T018 [US1] D3-010 / FR-009, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Display allergens on ingredients and recipes** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T019 [US1] D3-010 / FR-009, phase 3: **Display allergens on ingredients and recipes** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T018; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T020 [US1] D3-011 / FR-010, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Store favorites per member** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T021 [US1] D3-011 / FR-010, phase 3: **Store favorites per member** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T020; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T022 [US1] D3-018 / FR-011, phase 4: inspect existing evidence and add missing failing behavior/acceptance cases for **Rate recipes** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T023 [US1] D3-018 / FR-011, phase 4: **Rate recipes** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T022; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T024 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 3; reviewer Dev 1 and Dev 2; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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
