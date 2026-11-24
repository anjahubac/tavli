# Specification: Release, operations and repository collaboration

**ID**: 033-release-operations | **Feature key**: TEAM-SETUP
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Anja

## Scope and source

Implements the TEAM-SETUP portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Configure GitHub collaboration safeguards**. Source D3-003; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Integrate open changes safely**. Source D4-001; Dev 4; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Normal branches originate from current dev and PRs target dev; release dev→main uses merge commit, hotfix returns to dev.
- **FR-102**: Verify independent reviewers, required checks, default branch and protected environments with actual hosting capability; maintain a manual review gate where enforcement is unavailable.
- **FR-103**: Integrate existing open changes by explicit PR dependency/owner review; preserve unrelated dirty work and do not blindly choose one side of conflicts.
- **FR-104**: Security CI/deploy enforcement is implemented once under 012; test runners once under 013; reference the same implementation/evidence rather than duplicate jobs.

## User scenarios and acceptance

- **US1 / SC-001**: A normal feature PR targets dev and cannot bypass required review/check evidence before merge.
- **US2 / SC-002**: An integration conflict is resolved with affected owners and relevant tests; original user work remains intact.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Repository permissions, review policy and environment separation are operational configuration, not app data. Verify actual GitHub handles and plan capabilities; no fictional CODEOWNERS.

## Exact UI copy carried forward

No new UI copy in the initial technical slice.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

Producer specs: [012 security](../012-security-baseline/spec.md),
[013 testing](../013-testing-strategy/spec.md). Repository inventory can start independently.

- **Q1** (Dev 3 with reviewer): Verify reviewer GitHub handles, hosting ruleset availability, desired default branch and authorized settings operator; identify actual open PRs at execution time.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.

## Additional release and operations requirements

These requirements supplement the original TEAM-SETUP tickets; they are not
invented source CSV rows or permission to deploy this documentation branch.

- **FR-105**: Identify builds by version/build number, commit, platform and backend
  environment. Isolate dev/prod session/cache namespaces using 012's migration;
  a release cannot silently reuse another project's session or pending writes.
- **FR-106**: Define build, signing, distribution and update procedures for Android,
  iOS and macOS; add Windows only after 028 acceptance. Record artifact provenance,
  checksum, reviewer and actual store eligibility. Do not put signing material in Git.
- **FR-107**: Sequence additive server migration, compatible clients and any later
  cleanup. Test old-client/new-server combinations and offline queued payloads.
  A rollback must not blindly revert SQL or lose accepted user changes.
- **FR-108**: Release only a reviewed commit with applicable same-SHA tests and
  authorized production approval. Stage rollout where supported; retain a known
  compatible artifact and a documented stop/disable/forward-recovery procedure.
- **FR-109**: Define privacy-safe operational metrics (failure categories, latency,
  aggregate quota use), owners, alert thresholds and incident triage; no raw
  recipes, emails, tokens, health data or identifying record IDs in telemetry.
- **FR-110**: Verify actual backup capability/retention and rehearse restoration
  with synthetic data. Define recovery objectives from verified capability;
  don't promise an untested RPO/RTO or immediate erasure from backups.
- **FR-111**: Maintain support/release notes, platform compatibility, dependency
  update cadence and a redacted diagnostic collection procedure. Reuse security
  012's containment/rotation rules and testing 013's device/UX proof.

Additional acceptance:

- **SC-003**: A candidate is traceable to its commit/environment and its signed
  artifact; an incorrect environment or missing required check blocks release.
- **SC-004**: An older supported client uploads an offline queue after server
  migration without ownership/quantity loss; incompatible cleanup is deferred.
- **SC-005**: A synthetic failed rollout/restore exercise identifies who stops
  release, which compatible artifact is available and how data is recovered.

Open release decisions: actual store/signing access, support/update policy,
rollout mechanisms, backup service limits, measurable recovery/alert budgets
and authorized release approvers. These block affected release tasks, not the
creation of specs or independent local verification.
