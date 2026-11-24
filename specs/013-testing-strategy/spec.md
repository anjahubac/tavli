# Specification: test strategy and delivery confidence

**Status**: Draft implementation plan; each slice needs its recorded readiness
and setup decisions. No new runtime test infrastructure is implemented by this spec.
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Coordinator**: Dev 3 (CI), Anja (release acceptance); each developer tests their own feature.
**Review**: a different domain owner; AI review never replaces human review.

## Current evidence and goal

There are 64 Dart test files (domain 10, AI 6, data 8, sync 9, account 6,
features 20, app 5) and seven SQL test suites plus a helper file. Existing tests
use NativeDatabase.memory, FakeBackend/FakeAdapter, fake secure/photo storage,
injected clocks and pumpTavli/testTavli. These are file counts, not test results.
There is no integration_test directory or SDK integration_test dependency.
CI runs formatting/analyze and the complete Flutter suite; SQL, Edge and device
checks are not configured. The new documentation job is pending its first CI run.

Goal: prove core user outcomes and failure recovery at the appropriate level,
without duplicating every assertion in every layer or relying on live AI/hosted data.
Spec 012 owns security remediation; this spec owns reusable harnesses, CI execution
and journey coverage. It does not mark future features implemented merely to test them.

## User scenarios

- **US1 / P1**: A developer changes quantity logic; a deterministic unit test fails
  before the fix and existing shopping/repository regressions protect other sources.
- **US2 / P1**: A reviewer follows plan approval → missing ingredients → delta-only
  shopping → purchase/transfer → cooking/undo, with observable quantities at each
  boundary. Future pantry/cooking portions become gates when those features land.
- **US3 / P1**: Offline restart, account switch and a failed migration cannot lose
  queued edits or expose another account. Two local clients eventually converge.
- **US4 / P1**: A failed required test prevents merge/deploy for that exact commit;
  release device/UX evidence remains distinct from unit-suite success.

## Functional requirements

- **FR-001**: Maintain a baseline inventory and map critical requirements to tests,
  owners, test tier and evidence. Presence of a file does not establish coverage.
- **FR-002**: Domain/AI parser/router changes are test-first. Use table-driven
  invalid/boundary cases, not assertions that merely repeat implementation details.
- **FR-003**: Share deterministic fixtures with fake clock/IDs/provider/backend and
  teardown even after assertion failure. Every test has isolated DB/temp storage;
  no dependency on ordering, wall time, locale or another test's global state.
- **FR-004**: Widget tests cover key interactions, loading/error/empty/offline,
  keyboard/semantics, phone/wide, light/dark, 2× text and reduced motion.
- **FR-005**: Repository/sync tests prove row+outbox atomicity, replay idempotency,
  deletion, conflict, account isolation and same-supply accounting across sources.
- **FR-006**: Schema PRs test fresh creation and supported old-version upgrades with
  representative data and pending outbox; generated schema artifacts stay in sync.
- **FR-007**: Local SQL tests exercise grants, RLS, storage, RPC and parent-reference
  constraints with allowed and denied users. Edge tests use fake downstreams.
- **FR-008**: Add a small SDK integration_test harness for real app/device smoke
  flows with deterministic dependencies. Do not mislabel fake-backed journeys as
  proof of server integration or native permission-dialog behavior.
- **FR-009**: A separately invoked local-backend lane tests auth/sync/storage against
  ephemeral local Supabase only. Fail closed on a non-approved local endpoint;
  use synthetic accounts, throwaway storage and fake AI. Never load real secrets files.
- **FR-010**: Cover the critical journey matrix, including repeat Add, shared food,
  month boundaries, restart/replay, account switch and failure/cancellation.
- **FR-011**: Keep full Flutter CI on every PR. Add appropriate local SQL/Edge and
  device jobs incrementally; couple backend deploy to same-SHA required security
  checks with 012. Record hosted settings/hardware gaps rather than bypassing gates.
- **FR-012**: Report duration/coverage per owned area. Preserve the existing ≥80%
  domain/AI coverage target; measure baseline before enforcement. Critical behavior
  coverage is mandatory even if a line threshold passes; no meaningless coverage tests.
- **FR-013**: Treat flaky tests as defects: preserve the failing run and reproduction,
  fix with an owner; no skip/delete/threshold reduction or automatic retry-to-green.
- **FR-014**: Check affected-test selection on changed helpers, shared imports,
  deleted/renamed files and test infrastructure. It is a local optimization, never
  a replacement for full PR checks. Document its current limitations.
- **FR-015**: Release evidence covers supported platforms, native permissions,
  accessibility and first-use usability; Windows enters only with its platform spec.
- **FR-016**: Record command, SHA, environment, result, reviewer and remaining limits;
  keep artifacts redacted, bounded and free of personal data/secrets.

## Success criteria

- **SC-001**: Every critical journey has an owner and executable test or explicit
  future-feature/manual gate; no shipped critical path is unassigned.
- **SC-002**: New harness passes ten consecutive isolated runs and reproduces
  intentional failures without retry masking; normal suite remains offline.
- **SC-003**: Same-SHA failing Flutter/SQL/security evidence blocks its required
  merge/deploy gate; local-backend runner rejects a hosted URL before any request.
- **SC-004**: Upgrade/offline/retry fixtures preserve quantities, ownership and
  queued edits. Duplicate actions do not duplicate purchases, receipts or intake.
- **SC-005**: Device/UX checklist and measured coverage/durations are attached to
  release review; missing evidence stays open. No guarantee based solely on counts.

## Decisions before dependent work

Choose initial device runner/CI budget (recommend macOS smoke plus Android),
record supported cache upgrade versions, decide bounded artifact retention and
native-dialog automation versus documented manual proof. Native automation may
need an additional tool, which requires a separate dependency justification.
These decisions do not block deterministic unit/widget/SQL improvements.
