# Tasks: testing strategy implementation

All boxes remain open. Requirements are in spec.md; journeys in the contract.
Each task adds an exact PR/evidence link and remaining-effort estimate before Ready.
Cross-feature tests land with that feature, never fabricated around nonexistent UI.

- [ ] T001 Inventory assertion gaps/coverage/durations and map J01–J16 to current tests. Owner Dev 3 with all owners; reviewer Anja; FR-001/012; no dependency.
- [ ] T002 Harden test/helpers/test_app.dart teardown/isolation and fake time/IDs with failure-cleanup tests. Owner Dev 4; reviewer Dev 1; FR-003; depends T001.
- [ ] T003 Extend test/domain and test/data delta-add, shared supply, month/date and replay fixtures (J04–J07). Owner Dev 1; reviewer Dev 2; FR-002/005/010; depends T001.
- [ ] T004 Extend test/ai and recipe/planning widgets for malformed output, fallback, cancellation and stale drafts (J02/J03). Owner Dev 2; reviewer Dev 1; FR-002/010; depends T002.
- [ ] T005 Add supported-cache upgrade/fresh/outbox cases in test/data/migration_test.dart and schema fixtures (J10). Owner Dev 1; reviewer Dev 3; FR-006; depends supported-version decision.
- [ ] T006 Add auth/account-switch/session/deletion cases in existing account/feature tests (J01/J11). Owner Dev 3; reviewer Dev 4; FR-005/010; depends T002.
- [ ] T007 Extend UI matrix with targeted phone/wide/text/motion/focus/semantics tests, not every Cartesian combination. Owner Dev 4; reviewer affected feature owner; FR-004; depends T002.
- [ ] T008 Add test-infrastructure/affected-selection regression tests for helpers/imports/deletes/renames; document fallback. Owner Dev 3; reviewer Dev 1; FR-014; depends T001.
- [ ] T009 Add guarded ephemeral local-backend runner with synthetic setup/cleanup and zero-request hosted-URL rejection. Owner Dev 3; reviewer Dev 1; FR-007/009; depends 012 local-test contract.
- [ ] T010 Integrate SQL/Edge jobs and same-SHA deployment gate jointly with 012 T007/T008; one implementation PR, evidence linked in both specs. Owner Dev 3; reviewer Anja; FR-011; depends T009.
- [ ] T011 Add SDK integration_test dev dependency and isolated app/device harness; no third-party runner yet. Owner Dev 4; reviewer Dev 3; FR-008; depends T002 and runner selection.
- [ ] T012 Add small recipe→plan→shopping device smoke journey with fake AI and real local DB. Owner Dev 4; reviewer Dev 2; FR-008/010; depends T011.
- [ ] T013 Add separately invoked two-client local sync/restart test with offline/reconnect and account isolation. Owner Dev 1; reviewer Dev 3; FR-005/009; depends T009/T011.
- [ ] T014 Measure ten isolated harness runs, diagnose flakiness without skip/retry masking and attach evidence. Owner Dev 4; reviewer Dev 3; FR-003/013; depends T012/T013.
- [ ] T015 Add agreed device CI jobs, artifact bounds and coverage reporting; retain full Flutter gate. Owner Dev 3; reviewer Anja; FR-011/012/016; depends T014 and runner provisioning.
- [ ] T016 Record native permission/signing/wake-lock and UX release matrix; schedule five-person evaluation against implemented flows. Owner Anja; reviewer domain owners; FR-015; depends release candidate and applicable feature specs.
- [ ] T017 Attach J08/J14–J16 cases to each future feature's requirements/tasks; verify on that feature's release. Owner each feature owner; reviewer consumer; FR-010; depends respective producer contracts.
- [ ] T018 Validate full required gates and update testing guide with actual job/command/coverage evidence. Owner Dev 3; reviewer Anja; FR-016; depends applicable tasks, explicitly record deferred platform/feature gates.
