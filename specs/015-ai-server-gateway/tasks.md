# Tasks: Authenticated gateway for built-in AI

Status: quota reservation merged; Edge Function and Flutter transport changes
exist locally. Durable Flutter quota pauses, local Supabase verification and
release cutover are pending. Source roles/phases are preserved. Lead: Dev 2;
proposed reviewers: Dev 3 (choose a different human from the implementer).
Paths and contracts are in plan.md; finalize exact filenames and remaining
implementation/test/review estimates before Ready.

- [ ] T001 Resolve blocking questions in spec.md, agree typed contract/migration needs and acceptance fixtures. Owner Dev 2; reviewer Dev 3; depends on producer specs in plan.md; evidence: accepted decision/contract links.
- [ ] T002 [US1] D2-003 / FR-001, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Spike: send an image request through the gateway** at the tiers required by 013. Owner Dev 2; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T003 [US1] D2-003 / FR-001, phase 1: **Spike: send an image request through the gateway** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 2; reviewer independent domain consumer; depends T002; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T004 [US1] D2-004 / FR-002, phase 1: inspect existing evidence and add missing failing behavior/acceptance cases for **Move built-in AI credentials behind the server** at the tiers required by 013. Owner Dev 2; reviewer independent domain consumer; depends T001 and relevant producer; evidence: reproducible missing behavior or documented existing coverage.
- [ ] T005 [US1] D2-004 / FR-002, phase 1: **Move built-in AI credentials behind the server** using plan.md paths and its agreed contract; update consumers and docs. Owner Dev 2; reviewer independent domain consumer; depends T004; evidence: spec scenarios, applicable checks and reviewed PR.
- [ ] T006 Integrate consumer/release evidence, reconcile source ticket status and record unresolved limits. Owner Dev 2; reviewer Dev 3; depends on applicable implementation tasks; evidence: check commands/SHA/results and release decisions.

### Execution breakdown for T005 and T006

- [x] **T005a** Reuse the atomic quota reservation migration and its pgTAP fixtures. Merged in [PR #124](https://github.com/anjahubac/tavli/pull/124).
- [ ] **T005b** Review and merge the Edge Function, fake tests and deploy wiring. Server is implemented locally. Remaining evidence includes authenticated local Supabase integration and the same-SHA deployment gate in 012.
- [ ] **T005c** Add Flutter task IDs, discovery and completion transport, and account-safe retry/fallback/repair. Local code and fake transport tests exist. Integration verification on the merged T005b deploy remains pending.
- [ ] **T005d** Persist the current in-memory scoped quota pause and add migration tests. Coordinate drift schema version with Dev 1. Test restart, account switch and coexistence with BYOK.
- [ ] **T005e** Remove compiled provider credentials and old settings/test wiring (code: [PR #157](https://github.com/anjahubac/tavli/pull/157)). Verify all three dev flows from a build with only Supabase configuration and record key-free artifact evidence.
- [ ] **T006a** Record operator disable/rotation, compatible rollback, and dev→production approval evidence. Enabling OpenAI requires a separate model/quality and cost check.

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
