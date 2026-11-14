# Tasks: four-developer standardization

Scope: documentation/tooling plus the owner-approved Flutter 3.50 migration. These checkboxes describe this revision,
not completion of product features in the separate 87-task register.

- [x] T001 [US1] Inventory baseline Markdown/Spec Kit and actual main/dev architecture.
- [x] T002 [US2] Review the supplied plan and record contradictory/superseded decisions.
- [x] T003 [US1] Define ownership, review, branch/checkout, schema and integration rules in `docs/development/team-workflow.md`.
- [x] T004 [US3] Define AI context/brief/handoff/evidence rules in `docs/development/ai-development.md`.
- [x] T005 [US2] Revise architecture, product design, plan, roadmap and 010 overlay without changing app code.
- [x] T006 [US1] Add producer/consumer contracts and an English 87-task delivery register.
- [x] T007 [US3] Synchronize constitution, agent entry points and Spec Kit/PR templates.
- [x] T008 [US3] Add document/registry validation and CI documentation check.
- [x] T009 [US3] Run document/diff checks and complete review findings with evidence.

T001→T002→T005; T003/T004 use current architecture; T006 depends on ownership
and source review; T007 follows the accepted rules; T008/T009 validate all output.
No [P] declaration grants permission to edit the same shared files concurrently.
Team approval, verified GitHub handles/rulesets and runtime feature execution
remain external/future work, not hidden tasks claimed complete here.

- [x] T010 [US3] Assess current security boundaries and add `docs/development/security.md`, draft 012 and linked development/review gates; leave remediation tasks open.

- [x] T011 [US3] Prepare testing spec 013 and its journey/fixture/CI strategy.
- [x] T012 [US2] Prepare the full roadmap spec/plan/task/checklist set and map all 87 source tickets.
- [x] T013 [US1] Add release/operations 033 and reconcile indexes, testing lanes and shared gates.
- [x] T014 [US3] Validate the expanded spec/mapping set, run document-tool regression tests and format/analyze checks, and prepare the authorized documentation commit; the enabled pre-commit hook rechecks the staged scope.
- [ ] T015 [US3] Upgrade local/CI Flutter to 3.50.0, migrate Material imports and declare the dependency, preserve unrelated edits, and validate analyze/full tests/macOS debug build plus the PR workflow without suppressing diagnostics.
