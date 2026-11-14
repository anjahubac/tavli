# Tasks: Release, operations and repository collaboration

Status: planned, not completed. Source roles/phases are preserved. All source
tasks remain not_assessed until current code is checked. Lead: Dev 3;
proposed reviewers: Anja (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 3; reviewer Anja; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D3-003 / FR-001, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Configure GitHub collaboration safeguards** at the tiers required by 013. Owner Dev 3; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D3-003 / FR-001, phase 1: **Configure GitHub collaboration safeguards** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 3; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D4-001 / FR-002, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Integrate open changes safely** at the tiers required by 013. Owner Dev 4; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D4-001 / FR-002, phase 1: **Integrate open changes safely** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 4; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 3; reviewer Anja; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

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

## Additional operations tasks

- [ ] T007 Inventory actual release permissions, stores, signing, backup and runner capabilities; record gaps. Owner Dev 3; reviewer Anja; FR-105/106/110; no dependency; evidence: redacted inventory, no secret values.
- [ ] T008 Define version/artifact/environment manifest and verify dev/prod isolation via 012 evidence. Owner Dev 4; reviewer Dev 3; FR-105; depends 012 T011; evidence: wrong-environment rejection and correct upgrade.
- [ ] T009 Document/build signed candidate and platform update/distribution procedure without publishing. Owner Dev 4; reviewer Dev 3; FR-106; depends T007/T008 and supported platform acceptance; evidence: reproducible artifact and signing verification.
- [ ] T010 Test old-client/new-server, queued-write migration and forward recovery on synthetic data. Owner Dev 1; reviewer Dev 3; FR-107; depends active schema contracts and 013 upgrade fixtures; evidence: data-preserving compatibility matrix.
- [ ] T011 Connect same-SHA release/deploy evidence and authorized approval; reuse 012/013 implementation. Owner Dev 3; reviewer Anja; FR-108; depends T009/T010 and security gate; evidence: failed/stale check blocks release.
- [ ] T012 Define sanitized monitoring/alert thresholds, support diagnostics and operator handoff. Owner Dev 3; reviewers Dev 2/4; FR-109/111; depends privacy review; evidence: synthetic error reaches intended alert without sensitive payload.
- [ ] T013 Rehearse stop/disable/restore with local synthetic data; record actual recovery capability and retention. Owner Dev 1; reviewer Anja; FR-110; depends T007/T010/T012; evidence: timed drill and documented limits.
- [ ] T014 Assemble release notes, platform/support matrix, risk review and rollback/forward-recovery decision for candidate. Owner Anja; reviewers all owners; FR-106–111; depends applicable tasks; evidence: reviewed manifest, no implicit publication.

Before Ready, every operations task records a remaining effort range and a named
human reviewer other than its implementer. Publishing is a separate authorized step.

## Implemented tooling correction during documentation delivery

- [x] T015 Fix inherited worktree Git context in SDK subprocesses using `scripts/with-sdk-env.sh`; retain original Git context for staged selection and propagate command failures. Evidence: `scripts/test_sdk_env.py` foreign-checkout, exit-code, argument and usage tests. This is a narrow check-script fix, not completion of release infrastructure.
