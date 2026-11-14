# Tasks: Simple pantry and reversible consumption

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 4;
proposed reviewers: Dev 1 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 4; reviewer Dev 1; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D4-014 / FR-001, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **List and add pantry ingredients** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D4-014 / FR-001, phase 3: **List and add pantry ingredients** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D4-015 / FR-002, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Remove pantry ingredients with undo** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D4-015 / FR-002, phase 3: **Remove pantry ingredients with undo** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 [US1] D4-016 / FR-003, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Receive checked purchases into the pantry** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T007 [US1] D4-016 / FR-003, phase 3: **Receive checked purchases into the pantry** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T006; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T008 [US1] D4-017 / FR-004, phase 3: inspect existing evidence and add missing failing behavior/acceptance cases for **Consume and edit pantry quantities with reversal** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T009 [US1] D4-017 / FR-004, phase 3: **Consume and edit pantry quantities with reversal** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T008; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T010 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 4; reviewer Dev 1; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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
