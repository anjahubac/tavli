# Implementation plan: engineering standardization

Date: 2026-11-13. Branch: `docs/development-security-standards` (dev base).
Spec: [requirements](spec.md). Existing app remains Flutter/Dart, Riverpod,
go_router, drift, dio and Supabase; no new runtime dependency or schema.

## Approach

1. Read the supplied revision; inventory every tracked Markdown including hidden
   Spec Kit templates/agent skills, historical specs and platform asset notes.
2. Verify claims against main/dev refs, actual routes/providers/domain/schema,
   sync and existing CI/scripts. Separate stale status from unfinished acceptance.
3. Write current architecture and accepted product overlay, four-role ownership,
   AI session/brief/handoff rules, UI and validation/release gates.
4. Register the original 87 tasks in English with preserved owner/phase/order,
   plus cross-feature contracts and future feature clarification gates.
5. Synchronize constitution, AGENTS/CLAUDE, README, local Spec Kit templates and
   project-specific command guidance. Keep vendor extension code intact.
6. Add source-level security assessment and draft spec 012 in response to the
   owner's follow-up; runtime remediation remains separately tracked.
7. Prepare testing 013, all roadmap specs and release/operations 033; map every
   source task to a real requirement and test/implementation task without marking
   future runtime work complete.
8. Validate all active links, mappings, dependency cycles and script regression
   cases; run required pre-commit gates, record not-run checks and commit together
   on the owner-requested branch.

## Constitution check (v3.0.0)

| Gate | Result |
| --- | --- |
| I Serbian UI | Pass: English engineering docs; actual UI copy remains Serbian |
| II account/offline | Pass: existing outbox maintained; device-only sensitive exception explicit |
| III AIRouter | Pass: gateway is a planned transport, no direct feature client |
| IV secrets | Pass: no credential reads/writes; server-only built-in target |
| V tests | Pass: document validation appropriate; runtime gates remain mandatory |
| VI responsive | Pass: UI matrix/interaction standard, no runtime layout edits |
| VII reviewable changes | Pass: isolated documentation scope, user edits preserved |
| VIII feature/spec/branches | Pass: one process spec, branch from dev; existing checkout, one writer (v3.0.1 clarification) |
| IX architecture/guardrails | Pass: actual paths reused; generic examples overridden |
| X collaboration | Pass: owners, contracts, schema coordination and human review documented |

No exceptions or new dependencies. Constitution change is major because the
device-only data exception and built-in credential policy amend prior principles.

## Data/model/contracts

No database migration. The delivery register is documentation metadata with a
stable task ID, English title, source row, role, phase and feature key. Shared
runtime contracts are **requirements for later acceptance**, not invented live
method signatures. They live in [shared boundaries](contracts/shared-boundaries.md).

## Validation

Run `python3 scripts/check-docs.py` and `git diff --check`; inspect source/task
counts, source references and changed-file scope. Use the existing check/hook
commands if committing. This request does not require running the entire app
suite or builds for Markdown-only changes; do not report those checks as run.
CI still retains its full Flutter checks. Documentation review is pending until
the team reviews this branch.
