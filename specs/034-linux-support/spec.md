# Feature specification: Linux desktop support

**Spec ID:** 034-linux-support | **Status:** Draft | **Date:** 2026-11-19
**Baseline:** `origin/dev` at `c06fe5e` | **Owner:** Matija (Dev 3) | **Reviewer:** Anja (Dev 4)
**Source:** [Linux application](https://trello.com/c/4G5ajy0w) and [Linux CI](https://trello.com/c/kJ7ULfN0), phase 4.

## Scope and decisions

Support Ubuntu 24.04 LTS on x86_64 first. Deliver a runnable Flutter Linux bundle and a Linux build on every PR to `dev` or `main`; no installer or public release in this slice. Preserve the untracked `linux/` scaffold already in Matija's checkout and review it against Flutter 3.50.0 before use. Sign-in uses the existing email one-time code; adding an email-link callback is outside this slice. Validate every tab present at the PR's baseline; the planned fifth tab is tested when its own feature lands.

## Requirements

- **FR-001:** A clean Ubuntu 24.04 x86_64 build starts and supports sign-in, sign-out, session restoration, offline restart and account switching without exposing another account's cache.
- **FR-002:** Linux supports choosing or cancelling a recipe image, secure storage of the session and user keys, drift/SQLite and photo files, and the recipe screen wake-lock lifecycle. Failures show safe Serbian Latin text and leave the app usable.
- **FR-003:** The current tabs, keyboard focus, window resizing and 2× text remain usable. Existing phone/macOS behavior is preserved.
- **FR-004:** CI builds the Linux bundle for each PR without real credentials, while existing analysis and tests remain. Anja configures the Linux job as a required GitHub check if repository rules permit; until verified, CI success alone does not imply merge blocking.

## Acceptance scenarios

1. On a clean Ubuntu 24.04 x86_64 machine, install the documented build prerequisites, build and launch the bundle, sign in with a synthetic account through the email code, open every current tab, restart offline and recover the same account cache.
2. Switch between two synthetic accounts and confirm their cached records and secure sessions do not cross; sign-out retains the correct account's cached data.
3. Choose and cancel an image, exercise missing or invalid image input, and turn screen wake-lock on and off. An unavailable secure store reports a safe failure without writing secrets to ordinary files or logs.
4. A PR with a broken Linux build fails the Linux CI job. Verify separately whether GitHub branch rules prevent merging that PR.

## Data, security and delivery

No new server table or business-data format is intended. Session and user keys stay in the OS secure store; business data remains account-scoped in drift/outbox and Supabase. Validate local file paths and avoid logging email codes, tokens, keys, personal data or raw exception bodies. No new remote endpoint or AI route is introduced (abuse impact: N/A); no hosted deployment or public artifact is authorized. CI uses least-privilege permissions and no credentials. Apply [security baseline](../012-security-baseline/spec.md), [testing strategy](../013-testing-strategy/spec.md) and [quality gates](../../docs/development/quality-gates.md).

**New UI copy:** none planned. Any needed Linux-specific error or permission text must be specified here in Serbian Latin before implementation.

## Implementation preparation and evidence

Before planning, audit the existing Linux scaffold and plugin support, name exact shared files and coordinators with Anja, justify any dependency in `plan.md`, and check build prerequisites on the target machine. Separate the app target and CI into reviewable slices, each from the latest `origin/dev` with a PR to `dev`. Record build/test commands, SHA, real-machine smoke results, GitHub rule status and Anja's independent review. These results and a merged PR are required before either Trello card is Done.
