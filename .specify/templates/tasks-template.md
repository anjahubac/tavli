# Tasks: [FEATURE NAME]

**Spec / plan**: [links] | **Branch / baseline**: [branch / dev SHA]
**Owner / reviewer**: [different people] | **Feature key / Trello**: [links]

Tests for changed domain logic, AI parsing/router/error mapping are mandatory
and test-first under constitution V. Local two-account SQL tests are required
for access rules. UI flows need relevant widget/manual evidence. Documentation
changes use document checks; do not add meaningless runtime tests for prose.

## Task format

Use `- [ ] T001 [US1] ...` with real paths. Add `[P]` only if files and contracts
are independent, not simply because two developers are available. Every task
names an owner, reviewer, requirement, dependency and observable completion.
Split large work into reviewable slices; do not insert generic setup boilerplate.

## Contract and preparation

- [ ] T001 Record current behavior and agree producer/consumer contract in [path]. Owner: [Dev]; reviewer: [Dev]; FR: [ID]; depends: none; done: [evidence].

## User Story 1 — [outcome]

- [ ] T002 [US1] Add failing behavioral tests in [test/path]. Owner: [Dev]; reviewer: [Dev]; FR: [ID]; depends: T001; done: failure proves missing behavior.
- [ ] T003 [US1] Implement bounded change in [lib/path]. Owner: [Dev]; reviewer: [Dev]; FR: [ID]; depends: T002; done: acceptance/test evidence.
- [ ] T004 [US1] Integrate affected repository/sync/UI paths [paths]. Owner: [Dev]; reviewer: [consumer]; FR: [ID]; depends: T003; done: offline/undo/error tests pass.

## Verification and handoff

- [ ] T005 Run applicable checks, record actual results, update docs and provide handoff. Owner: [Dev]; reviewer: [Dev]; depends: T004; done: evidence and PR linked.

## Dependencies and effort

| Task | Blocked by / producer PR | Implementation | Tests | Review/integration | Confidence |
| --- | --- | --- | --- | --- | --- |
| [ID] | [IDs] | [range in days] | [range] | [range] | [low/medium/high] |

Check boxes only when the specified result exists; mark delivery Done after
independent review and merge. Preserve historical acceptance evidence. Report
not-run checks and external setup separately. Never replace tests with an AI claim.
