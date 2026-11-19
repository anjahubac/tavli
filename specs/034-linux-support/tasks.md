# Tasks: Linux desktop support

**Spec/plan:** [spec](spec.md) · [plan](plan.md) | **Owner/reviewer:** Matija / Anja | **Status:** open

- [ ] **T001 — Audit and agreement (FR-001–004):** Inspected the untracked GTK scaffold and cached plugin metadata. Documented Linux file picking/camera limitation, secure-store libsecret/keyring requirements and DBus wake-lock support in `plan.md`. No fallback or dependency change is currently indicated. Review with Anja and confirm build prerequisites during T002. Evidence: source audit; build/runtime behavior remains unverified.
- [ ] **T002 — Linux app behavior (FR-001–003):** On a fresh branch from `origin/dev`, complete `linux/` and necessary existing adapters. Cover email-code sign-in, secure session/key storage, account isolation, offline restart, image pick/cancel, SQLite/photos and wake-lock failure paths. Depends: T001. Evidence: applicable automated tests and a successful Linux debug build.
- [ ] **T003 — Real-machine acceptance (FR-001–003):** On Ubuntu 24.04 x86_64, use synthetic accounts to run the spec's sign-in, restart, account-switch, file, wake-lock, current-tab, keyboard, resize and 2× text scenarios. Depends: T002. Evidence: redacted command/SHA/result record; Anja's independent review before app PR merge.
- [ ] **T004 — Linux CI (FR-004):** After the app PR merges, branch from fresh `origin/dev` and add the Linux build job in `.github/workflows/check.yml`; preserve existing jobs and least-privilege permissions. Depends: T003 and app PR merge. Evidence: passing PR build and a controlled failing-build check.
- [ ] **T005 — Merge protection and handoff (FR-004):** Anja verifies/configures the Linux required check if GitHub rules permit; record actual settings or the manual merge control. Link CI evidence and independent review, then reconcile both Trello cards. Depends: T004. Evidence: verified rule status and merged PR; do not mark Done earlier.

No new schema, SQL, sync format, endpoint or AI task is expected. Separate unexpected scope into a reviewed spec/plan update. Tests use fakes or the guarded local backend, never hosted data or real keys.
