# Tasks: Shared ingredient catalog and matching

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 1;
proposed reviewers: Dev 2 and Dev 3 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 1; reviewer Dev 2 and Dev 3; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D1-001 / FR-001, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Agree the ingredient model** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D1-001 / FR-001, phase 1: **Agree the ingredient model** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D1-005 / FR-002, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Create ingredient catalog tables** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D1-005 / FR-002, phase 2: **Create ingredient catalog tables** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 [US1] D1-006 / FR-003, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Review and seed 300–400 ingredients** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T007 [US1] D1-006 / FR-003, phase 2: **Review and seed 300–400 ingredients** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T006; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T008 [US1] D1-007 / FR-004, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Resolve ingredient names through the shared matcher** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T009 [US1] D1-007 / FR-004, phase 2: **Resolve ingredient names through the shared matcher** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T008; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T010 [US1] D1-008 / FR-005, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Map existing recipe ingredients to the catalog** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T011 [US1] D1-008 / FR-005, phase 2: **Map existing recipe ingredients to the catalog** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T010; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T012 [US1] D1-009 / FR-006, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Provide unresolved-ingredient review UI** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T013 [US1] D1-009 / FR-006, phase 2: **Provide unresolved-ingredient review UI** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T012; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T014 [US1] D1-010 / FR-007, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Support ingredient-specific units and conversions** at the tiers required by 013. Owner Dev 1; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T015 [US1] D1-010 / FR-007, phase 2: **Support ingredient-specific units and conversions** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 1; reviewer independent domain consumer; depends T014; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T016 [US1] D2-008 / FR-008, phase 2: inspect existing evidence and add missing failing behavior/acceptance cases for **Generate catalog-ready ingredient data** at the tiers required by 013. Owner Dev 2; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T017 [US1] D2-008 / FR-008, phase 2: **Generate catalog-ready ingredient data** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 2; reviewer independent domain consumer; depends T016; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T018 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 1; reviewer Dev 2 and Dev 3; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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
