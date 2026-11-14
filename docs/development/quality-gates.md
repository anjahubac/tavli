# Quality gates and environments

These are required evidence by change type, using existing repository commands.
Check names below describe current configuration or explicitly planned work;
writing them here does not configure GitHub branch protection.

| Change | Required local evidence | Integration/release evidence |
| --- | --- | --- |
| Documentation/Spec Kit only | `python3 scripts/check-docs.py`, `git diff --check` | documentation CI; no app tests invented for prose |
| Dart/UI/domain | `scripts/check.sh`, affected tests | full `flutter test` in CI; phone/wide matrix for UI |
| Shared data/AI/router | failing behavioral tests then implementation; full suite before PR | reviewer verifies failure/offline/cancellation/undo boundaries |
| drift schema | version bump, upgrade/fresh-cache test, generated output | pending-outbox/account-switch regression |
| SQL/RLS/storage | local `supabase db reset`, `supabase test db` | two accounts, ownership, allowed/denied reads/writes, deletion |
| Edge Function | fake provider/auth/limits tests, local function checks | local authenticated integration, no hosted test calls |
| Dependency/platform | separate PR, plan justification, affected platform build | Android/iOS/macOS as applicable; Windows only after target exists |
| Release | full suite, macOS debug smoke build, local backend tests, UX evidence | tested dev artifact, production approval, compatibility/rollback notes |

Before each commit, run `dart format lib test scripts` when Dart changed; the
existing pre-commit hook runs check + affected tests. Do not bypass it. Preserve
CI's full-suite behavior even for documentation PRs; optimizing CI requires a
separate measured change. No real AI/provider/backend keys in tests.

## Current infrastructure versus required setup

The supported Flutter toolchain is **3.50.0 stable**. Use that version locally;
`.github/workflows/check.yml` pins the same release so a new stable release
cannot silently change PR checks. SDK upgrades need a dedicated change with
analyze, full tests and affected platform evidence. App and test Material widgets
come from the explicit `material_ui` dependency, following the
[official migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).
Keep analyzer diagnostics enabled; do not mix legacy Flutter Material types with
standalone package types.

Current `.github/workflows/check.yml` runs format/analyze and full Flutter tests;
`pr-conventions.yml` checks names and PR titles; `deploy-supabase.yml` deploys
on supported `dev`/`main` changes. The docs job added with 011 validates active
Markdown/registry consistency; the separate scripts job runs every script
regression test (`scripts/test_*.py`). macOS, SQL/pgTAP and future Windows checks are
not silently claimed to be current CI jobs: each needs a dedicated setup task.

Dev 3 records actual repository plan/ruleset availability and required checks
before enabling restrictions. Require independent review and green checks on
both branches where supported. If the hosting plan cannot enforce this, use a
documented manual merge checklist; never say a textual rule is enforced.

## Local, development and production

- Local Supabase: API 55321, DB 55322, Studio 55323, mail 55324. Synthetic data
  only; resets/tests run here.
- Hosted dev: `dev` → `tavli-dev`. Test builds use the team's gitignored
  environment file through `--dart-define-from-file`; do not read it in agents.
- Production: `main`, only reviewed release/hotfix flows; GitHub `production`
  environment approval is an external setup to verify.

Do not manually change hosted tables, RLS, function secrets or auth settings
as part of an unrelated feature. A migration deployment requires the SQL tests
and compatibility evidence first; CI deployment existing today does not by
itself prove those checks ran. SQL/Edge validation automation is a phase-1
infrastructure deliverable, not implemented by this documentation revision.

## Release and recovery checklist

Record build SHA/version and intended platform; test sign-in and deep links,
offline restart and replay, account switching, household isolation and deletion.
Verify all critical migration paths and confirmed shopping quantities. A release
cannot require hidden data resets to succeed. For additive schema changes,
document older-client support and forward recovery; do not propose rolling
back applied SQL blindly. Any destructive repair needs its own reviewed plan
and explicit authorization. Store links and QR codes remain unavailable until
real distribution URLs are supplied; Windows is planned until its build is proven.

## Security evidence

Apply [security baseline](security.md) and
[012 matrix](../../specs/012-security-baseline/contracts/security-test-matrix.md).
Auth/RLS/storage/gateway/file/CI changes need negative cases as well as happy
paths. Resolve High findings before affected release. The required same-SHA
backend test/deploy dependency is planned in 012; current deployment YAML does
not enforce it. No hosted settings were inspected or changed in this revision.

Testing-lane clarification (013): normal Flutter unit/widget tests use fakes and
no network. A separately invoked endpoint-guarded integration runner may use only
ephemeral local Supabase with synthetic accounts and fake AI. This exception is
not permission to read secrets files, probe hosted services or weaken default
checks. See `specs/013-testing-strategy/` and `docs/development/testing.md`.
Release 033 coordinates artifacts and recovery; 012 owns security gates, 013
owns their execution infrastructure. Implement shared CI work once and link evidence.

SDK invocation note: `scripts/with-sdk-env.sh` clears repository-local Git
variables only inside Dart/Flutter subprocesses. This prevents worktree hooks
from making Flutter identify the app repository as its SDK checkout. The parent
keeps its Git/index context for affected-file selection; command failures still
propagate and both pre-commit checks remain enabled. The Python regression suite
runs in the documentation/tooling CI job.
