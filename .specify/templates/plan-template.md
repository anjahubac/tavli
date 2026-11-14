# Implementation Plan: [FEATURE]

**Spec**: [relative link] | **Date**: [YYYY-MM-DD] | **Baseline**: [dev SHA]
**Branch / PR base**: [branch] / dev
**Owner / reviewer**: [names] | **Status**: Draft / Ready / In progress

## Summary

[Behavioral change, existing components reused, smallest deliverable.]

## Technical Context

Tavli uses Flutter/Dart, Riverpod, go_router, drift, Supabase and AIRouter.
Take exact versions from pubspec.yaml/lock; do not assume a new framework.
Existing folders: lib/app, lib/features, lib/domain, lib/data, lib/ai,
lib/account, lib/sync, test, supabase/migrations, supabase/tests, supabase/functions.
[Specify actual files affected and existing providers/repositories to reuse.]

## Constitution Check

Evaluate all gates before implementation and after design. Cite evidence or
explain N/A; unresolved violations block Ready unless the constitution is amended.

| Principle | Pass / N/A / blocked | Evidence |
| --- | --- | --- |
| I Serbian UI; English engineering docs | [status] | [copy/docs] |
| II Offline, account ownership, privacy exceptions | [status] | [data flow] |
| III AIRouter and validated AI | [status] | [contract/fakes] |
| IV Secrets and safe diagnostics | [status] | [storage/transport] |
| V Test-first domain/parsing; local backend tests | [status] | [test cases] |
| VI Responsive/accessibility | [status] | [UI matrix] |
| VII Reviewable changes/generated files | [status] | [slices] |
| VIII Canonical spec, owned branches from dev | [status] | [branch/context] |
| IX Existing architecture and guardrails | [status] | [files/dependencies] |
| X Shared contracts and human review | [status] | [owners/contracts] |

## File and responsibility map

| Existing/new path | Change | Owner | Consumer/reviewer |
| --- | --- | --- | --- |
| [real path] | [bounded change] | [Dev] | [Dev] |

Keep feature providers beside their feature; shared wiring stays lib/providers.dart.
Do not invent new services/packages merely to divide work between people.

## Contracts and data changes

[Input/output fields, validation, IDs/units/dates, fake interface and producer/
consumer acceptance. Link contracts/ and data-model.md when applicable.]
[Current→target drift version, upgrade/pending-outbox tests, generated files,
new SQL/RLS/grants/storage/membership tests, sync registry and deletion behavior.]
For no data changes, state that explicitly; never guess a future schema version.

## Dependencies and delivery order

[Producer PR first, independent fakes, consumers after merge; shared-file coordinator.
Remaining implementation/test/review effort range and confidence per slice.]
New dependencies need a one-line reason here. State None when none are added.

## Validation and rollout

[Commands and behavioral cases from quality-gates.md; phone/wide/text/motion
checks; old-client compatibility, feature/offline failure and recovery.]
[Local/dev/production sequence, release evidence and forward recovery. No direct
hosted writes, destructive reset or claim that GitHub settings are configured.]

## Complexity Tracking

| Deviation / risk | Why needed | Simpler option | Resolution / owner |
| --- | --- | --- | --- |
| [none or concrete risk] | [reason] | [alternative] | [decision] |

## Security implementation impact

[Read docs/development/security.md and 012. Map threat → existing boundary →
control → negative test → owner. Record real hosted-setting/deployment dependency
checks separately from local source evidence; never claim a control is configured
because a document requests it. No new credentials or production probes.]
