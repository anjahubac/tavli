# Tasks: security baseline

All implementation tasks remain open. These are additional security slices, not
new completion claims or a rewrite of the original 87 Trello product tickets.
Before Ready, attach Trello/PR, confirmed human reviewer, actual paths and an
effort range for implementation + tests + integration. “Dev” denotes ownership.

- [ ] T001 [US3] Add failing containment tests in test/data/recipe_photo_store_test.dart and test/sync/ for traversal, absolute/separator/snapshot input and valid photos. Owner Dev 1; reviewer Dev 4; FR-004; no dependencies.
- [ ] T002 [US3] Validate names/root containment in photo store and sync conversion, including read/write/delete; preserve valid migration paths. Owner Dev 1; reviewer Dev 4; FR-004; depends T001.
- [ ] T003 [US2] Add failing synthetic-sensitive error/UI/attempt tests in test/ai/ and test/features/settings/. Owner Dev 2; reviewer Dev 3; FR-003; no dependencies.
- [ ] T004 [US2] Replace raw provider/error propagation across client/router/UI with safe categories. Owner Dev 2; reviewer Dev 3; FR-003; depends T003.
- [ ] T005 [US1] Extend local supabase/tests coverage for role/parent-ID/RPC/object-path isolation and rejected ownership changes. Owner Dev 3; reviewer Dev 1; FR-001; no dependencies.
- [ ] T006 [US1] Add local delete-account function auth/failure/retry fixtures; agree recent-auth requirement before changing behavior. Owner Dev 3; reviewer Dev 1; FR-005/008; depends T005.
- [ ] T007 [US4] Add local SQL/function CI with reproducible synthetic setup and no hosted credentials. Owner Dev 3; reviewer Anja; FR-009; depends T005/T006.
- [ ] T008 [US4] Gate backend deployment on reviewed same-SHA security evidence; prove a failing check prevents deploy. Owner Dev 3; reviewer Anja; FR-009; depends T007.
- [ ] T009 [US2] Link accepted gateway producer contract and exact limits/retry policy to security matrix; avoid duplicating Dev 2 gateway tickets. Owner Dev 2; reviewer Dev 3; FR-002; depends accepted AI-GATEWAY contract.
- [ ] T010 [US2] Verify gateway invalid-token, forged-user, size/concurrency/quota/destination and cutover behavior; zero provider calls for rejected requests. Owner Dev 2; reviewer Dev 3; FR-002; depends T009 and gateway implementation.
- [ ] T011 [US3] Record environment/account namespace and cache protection decision with migration and backup policy. Owner Dev 3; reviewers Dev 1/4; FR-006/007; no dependencies.
- [ ] T012 [US3] Implement agreed isolation migration with fresh/upgrade/offline-outbox/account-switch tests and retained-data recovery. Owner Dev 3; reviewers Dev 1/4; FR-006; depends T011.
- [ ] T013 [US3] Verify release platform storage, backup, screen/clipboard exposure and sensitive-data gate on supported devices. Owner Dev 4; reviewer Dev 3; FR-007; depends T011/T012.
- [ ] T014 [US2] Record redacted environment auth/redirect/OTP/rate-limit and destructive-operation evidence; authorized operator verifies hosted settings. Owner Dev 3; reviewer Anja; FR-005; depends T006.
- [ ] T015 [US4] Add reviewed action/SDK pinning, stack-appropriate secret/dependency scanning and release-signing checks; record hosting limitations. Owner Dev 3; reviewer Anja; FR-010; depends tool-choice review.
- [ ] T016 [US1] Bind household removal/transfer/invite and queued-write security cases to 008 and realtime to 009 before their releases. Owner Dev 3; reviewer Dev 1; FR-008; depends household contracts.
- [ ] T017 [US1] Bind RAG/import/voice/cycle input, retrieval, deletion and privacy gates to owning feature specs. Owner Dev 2; reviewers Dev 3/4; FR-011; depends respective contracts, not current release.
- [ ] T018 [US4] Complete release risk review and local synthetic incident/restore exercise, link evidence and resolve High findings before affected release. Owner Anja; reviewers all domain owners; FR-012; depends applicable release tasks above.

Ready now for detailed scoping: T001/T003/T005/T011. Implementation requires a
separate branch and actual tests; this documentation change fixes none of SEC-01–08.
