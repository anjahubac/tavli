# Tasks: Linux desktop support

**Spec/plan:** [spec](spec.md) · [plan](plan.md) | **Owner/reviewer:** Matija / Anja | **Status:** open

- [x] **T001 — Audit and agreement (FR-001–004):** Inspected the GTK scaffold and plugin metadata. Recorded file-picker limits, secure-store libsecret/keyring requirements and DBus wake-lock support in `plan.md`. No fallback or package change is indicated by source audit. Anja remains the independent PR reviewer. Evidence: source audit and installed Ubuntu build packages.
- [x] **T002 — Linux app behavior (FR-001–003):** Review and complete `linux/` and necessary existing adapters. Cover email-code sign-in, secure session/key storage, account isolation, offline restart, image pick/cancel, SQLite/photos and wake-lock failure paths. Depends: T001. Evidence: Linux debug build, `scripts/check.sh`, full `flutter test` suite, and owner-reported manual testing all passed; platform files are included in PR #67.
- [x] **T003 — Real-machine acceptance (FR-001–003):** Validate sign-in, restart, account-switch, file, wake-lock, current tabs, keyboard, resize and 2× text on Ubuntu 24.04. Depends: T002. Evidence: owner reports all manual scenarios passed (2026-11-19); checkout environment Ubuntu 24.04.3 LTS; `flutter build linux --debug` passed at `42f32afc9b0d1db1b05caba020af116b40c2c5cf`.
- [ ] **T004 — Linux CI (FR-004):** After the app PR merges, branch from fresh `origin/dev` and add the Linux build job in `.github/workflows/check.yml`; preserve existing jobs and least-privilege permissions. Depends: T003 and app PR merge. Evidence: passing PR build and a controlled failing-build check.
- [ ] **T005 — Merge protection and handoff (FR-004):** Anja verifies/configures the Linux required check if GitHub rules permit; record actual settings or the manual merge control. Link CI evidence and independent review, then reconcile both Trello cards. Depends: T004. Evidence: verified rule status and merged PR; do not mark Done earlier.

No new schema, SQL, sync format, endpoint or AI task is expected. Separate unexpected scope into a reviewed spec/plan update. Tests use fakes or the guarded local backend, never hosted data or real keys.
