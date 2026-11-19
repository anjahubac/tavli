# Plan: Linux desktop support

**Spec:** [034](spec.md) | **Baseline:** `origin/dev` `c06fe5e` | **Owner/reviewer:** Matija / Anja | **PR base:** `dev`

## Approach and boundaries

1. Review Matija's untracked `linux/` Flutter scaffold against SDK 3.50.0. Audit `flutter_secure_storage`, `image_picker`/file selector, drift/SQLite, `path_provider` and `wakelock_plus` on Ubuntu 24.04 x86_64. Preserve the existing email-code flow.
2. Complete one Linux app slice: `linux/` and only necessary changes in `lib/ai/key_store.dart`, `lib/account/`, `lib/features/recipes/` or `lib/providers.dart`. Anja coordinates platform/UI and shared-file changes. No schema or Supabase changes are planned.
3. After the app slice is merged, add a separate Linux build job in `.github/workflows/check.yml` with Flutter 3.50.0, documented Ubuntu build packages and no credentials. Keep existing jobs. Anja checks GitHub rules and enables the required check if permitted; otherwise record that it is manual.

Audit evidence (source/package metadata only): the untracked scaffold is standard GTK; generated registration includes `file_selector_linux` and `flutter_secure_storage_linux`. `image_picker_linux` uses file selection; camera is unsupported, and its resize/quality options are ignored (the app resizes after reading bytes). Secure storage uses libsecret and requires `libsecret-1-dev` to build, `libsecret-1-0` plus a running keyring at runtime. `wakelock_plus` declares Linux support through DBus. No clean Linux build or real-machine behavior has been verified. CI currently runs analyze/tests on Ubuntu but no Linux build. `windows/` is still absent.

**Dependencies:** No new Dart package planned. If the audit reveals one, add its one-line justification here before changing `pubspec.yaml`. Linux system packages and any plugin fallback must be fixed from build evidence, not guessed. No database migration, new remote endpoint or AI change is planned.

## Constitution check

| Principle | Design response |
| --- | --- |
| I | Engineering docs in English; specify any new Serbian Latin error copy in spec first. |
| II | Retain per-account drift/outbox behavior and device-only secrets; verify offline restart/account switch. |
| III | N/A: no new AI call; existing `AIRouter` stays. |
| IV | OS secure store only; no credentials or personal data in CI/logs. |
| V | Meaningful auth/storage/image failure tests and real-device proof; no SQL change. |
| VI | Check current tabs, keyboard, resizing and 2× text; fifth tab follows its own feature. |
| VII | App and CI in separate reviewable PRs; generated files only via Flutter. |
| VIII | Canonical 034 spec; each slice branches from current `origin/dev` into `dev`. |
| IX | Reuse existing platform adapters; justify any new dependency before adding it. |
| X | Matija implements; Anja reviews and coordinates platform/CI ownership. |

## Verification and handoff

App slice: `scripts/check.sh`, relevant Flutter tests, `flutter test` for shared code, `flutter build linux --debug`, then a real Ubuntu 24.04 x86_64 smoke run with synthetic accounts. Check secure-store unavailable, image cancellation, offline restart and account separation; record command, SHA and outcome. CI slice: prove a deliberately broken Linux build fails the job without weakening existing checks; verify branch protection separately. No hosted backend probe, public bundle or release is part of these PRs. Use [012](../012-security-baseline/spec.md), [013](../013-testing-strategy/spec.md) and [quality gates](../../docs/development/quality-gates.md).

**Open evidence:** plugin audit, exact Linux build prerequisites, manual smoke results and GitHub ruleset access. If a plugin lacks Linux support, choose a reviewed fallback and update this plan and spec before implementation.
