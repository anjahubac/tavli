# Implementation plan: testing

**Spec**: [013](spec.md) | **Status**: planned infrastructure, not implemented
**Baseline**: dev 207c94c | **Owners**: Dev 3 CI; Dev 1 data; Dev 2 AI; Dev 4 UX/device

## Existing structure and proposed additions

Keep test/domain, test/ai, test/data, test/sync, test/account, test/features,
test/app and test/helpers. Extend existing FakeBackend/FakeAdapter and injected
clocks rather than introduce a mock framework. Improve testTavli cleanup so
assertion failures still dispose providers, DB, timers, views and temporary files.

Proposed integration_test/helpers and a few *_test.dart journeys are new paths,
not current infrastructure. Proposed scripts/test-backend.sh and
scripts/test-integration.sh separate explicit lanes and endpoint guards. Final
filenames/job names are selected in the implementing PR, with this plan updated.
Existing scripts/check.sh and test-changed.sh remain the fast pre-commit entry.

## Dependency decision

Planned dev dependency: Flutter SDK integration_test, justified by real app/device
smoke execution beyond widget tests. Do not add it in the documentation commit.
No additional mocking, golden or native UI automation package is selected.
Flutter SDK integration tests cannot directly drive native permission dialogs;
keep device/manual proof until a justified runner is accepted.
[Flutter integration guidance](https://docs.flutter.dev/testing/integration-tests)
and [native plugin testing](https://docs.flutter.dev/testing/testing-plugins).

## Implementation order

1. Inventory existing assertions and gaps against the matrix; capture baseline
   full-suite results/coverage/duration without pretending current counts are passes.
2. Harden isolated fixtures/teardown, add deterministic regression cases by domain.
3. Dev 1 validates migration paths and local SQL fixtures; Dev 3 adds local backend
   and Edge runner/CI with the same-SHA deployment contract owned in security 012.
4. Dev 4 adds SDK integration harness and current core journeys; Dev 2 supplies
   valid/invalid/cancelled AI responses. Future flows are added in feature PRs.
5. Add platform jobs when runners exist; measure stability before requiring them.
   Full Flutter remains required throughout; backend deployment cannot bypass its
   required SQL/security evidence while a device runner is being provisioned.
6. Review coverage gaps and release checklist; owners demonstrate the complete
   supported journey and failure recovery with synthetic data.

## Migration and test data

No runtime schema change required by the test strategy itself. Use existing
v3_schema/v4_schema fixtures; agree supported upgrades and capture subsequent
schema snapshots through drift tooling, never by hand-editing generated output.
Test behavior/data preservation in addition to schema shape. See
[drift migration tests](https://drift.simonbinder.eu/migrations/tests/).

Default unit/widget tests have no network. The explicit local-backend lane may
connect only to a verified local Supabase origin (emulator host alias explicitly
mapped when needed). Guard before startup/reset/network calls; fixed synthetic
config, no secrets*.json, no production/service-role key files. Test-only local
admin setup remains outside the distributed app and uses ephemeral local values.
A failed endpoint guard must make zero requests and never reset any database.

## Constitution check (3.0.0)

I: English docs/Serbian test UI. II: offline/ownership invariants and device-only
exceptions tested. III: fake AI through AIRouter. IV: no real secrets/network.
V: test-first and explicit local-only integration lane. VI: adaptive/a11y matrix.
VII: small harness/domain/CI slices. VIII: canonical 013, owned dev-based branches.
IX: existing stack/fixtures, justified SDK dependency. X: each feature owner tests
and a different human reviews; Dev 3 coordinates CI, not all test writing.

## Performance, coverage and rollback

Record cold/warm suite durations first; split expensive device checks by release
risk rather than invent an unmeasured time budget. Benchmark representative
month/large recipe list and sync batches with fixed data/device description;
set regression bounds after measurement. No live AI benchmark in CI.
Coverage excludes generated/vendor code by a reviewed rule; gaps need meaningful
assertions, not a lower threshold. CI/harness rollback may not remove mandatory
protection; retain an explicit equivalent manual release gate when infrastructure
is unavailable. Never roll back applied production schema to test migrations.
