# Calendar-date cutover proposal

**Status:** Draft for review; not an approved migration or implemented fix.
**Source:** D1-002 / FR-001 in [016](spec.md), Trello card
[Datumi bez vremenske zone](https://trello.com/c/HLtlyVWL/16-datumi-bez-vremenske-zone).
**Owner:** Dev 1. **Proposed independent reviewer:** Dev 2, with affected data
owners reviewing migration and sync behavior.

## Existing representation

At team `dev` commit `928d655b32035d752332763840cc5c4b0e281697`, the intended
calendar-day columns are:

| Logical value | Server column / type | Local drift column |
| --- | --- | --- |
| Plan start and end | `meal_plans.start_date`, `end_date`: `timestamptz`, required | `startDate`, `endDate`: `DateTime`, required |
| Meal day | `meal_plan_entries.date`: `timestamptz`, required | `date`: `DateTime`, required |
| Shopping period | `shopping_lists.period_start`, `period_end`: nullable `timestamptz`, both present or both absent | `periodStart`, `periodEnd`: nullable `DateTime` |

The repository creates intended calendar values as UTC midnight using
`CivilDate.toWire()`. The sync entity sends UTC timestamps, while its existing
reader parses input and converts to local time; consumers interpret calendar
fields using `CivilDate.fromWire()`. Local schema version is 5 at this baseline.
`created_at` and other event times are instants and are outside this change.
Pantry expiry is excluded pending its separate product decision.

The shopping period has ordering and uniqueness constraints; a future
conversion needs to detect and resolve any collision before changing them.
Changing a type alone does not prove existing historical values all followed
the intended UTC-midnight convention. The source time zone of exceptional
legacy timestamps may not be recoverable from the timestamp alone.

## Reproducible compatibility evidence

The attached [synthetic fixture](fixtures/civil_date_wire.dart.txt) exercises
the actual team sync entities with both timestamp and date-only input, year
boundaries, DST dates and null shopping periods. It is a manually invoked
future-compatibility check and is not included in the normal test suite.
From a checkout at the baseline above, with Flutter 3.50.0 and dependencies
already installed:

```sh
cp specs/016-calendar-date-storage/fixtures/civil_date_wire.dart.txt /tmp/tavli-civil-date-wire-test.dart
TZ=Europe/Belgrade flutter test --no-pub /tmp/tavli-civil-date-wire-test.dart --reporter expanded
```

Observed on the baseline: 4 cases pass and 5 fail. In particular, input
`2026-12-31` is read as `2026-12-30`; a timestamp representing midnight UTC
retains its expected day. The invalid date-only input is also normalized
instead of rejected. These are synthetic inputs; the current server columns
still use timestamps, so this does not establish that existing hosted rows
currently return date-only values or that all current dates are incorrect.

An uncommitted prototype in a separate local checkout based on the earlier
`207c94c` baseline recognizes date-only input before the existing timestamp
reader. With its own Flutter 3.47.9 dependencies, the same nine fixture cases
passed separately in `Europe/Belgrade` and `America/Los_Angeles`. That evidence
is not a test of this PR, the current 3.50.0 application, a server migration,
offline replay or two-device synchronization. The prototype has not been
integrated or accepted.

## Proposed sequence for review

1. Agree the meaning of existing timestamp values and how to handle exceptional
   non-midnight values. Define a privacy-preserving, non-production validation
   of conversion collisions and ambiguous records; do not infer original device
   zones from timestamps.
2. Specify and test a compatible reader on the current team baseline for both
   old timestamps and valid date-only values, preserving event timestamps.
   Include old cache upgrades, real drift serialization, DST and the supported
   client/platform matrix. This prepares a client; it does not authorize a
   server type change.
3. Agree a server/client cutover that covers already-installed and offline
   clients. Verify how queued old writes, interrupted sync, retries, concurrent
   edits, account/household switching and downgrade are handled. Existing
   `SyncEngine.onStart()` and `onResume()` push before pulling, so simply
   upgrading a reader does not resolve the pending-outbox question.
4. Only after an enforceable or otherwise verified cutover and recovery path
   are accepted, implement a separately reviewed additive migration and local
   cache upgrade. Preserve IDs, constraints, approved snapshots and queued user
   changes. Do not mutate an applied SQL migration or preallocate a drift schema
   version before integration.
5. Validate fresh install and upgrades, two-device replay and PostgreSQL/RLS
   behavior on an ephemeral local stack. Document forward recovery and what
   happens if a client returns after a long offline period. Hosted deployment
   remains the team's CI responsibility and is not part of this proposal.

## Fresh database option raised in review

A disposable local database can be recreated from the checked-in migration
chain when validating the new PostgreSQL types. Before applying this option
to any shared environment, the schema coordinator must confirm that it has no
data to preserve and that no supported clients have pending writes. A local
reset does not settle the handling of installed clients or offline caches.

The compatibility reader is being verified in #42, including equality with
the UTC-midnight values used for shopping week lookups. The server-side slice
still needs tests for all five date fields, timestamp fields that must stay
instants, and shopping ordering and uniqueness. Use the existing requirement
to add a new migration to the chain instead of editing an applied migration.

## Decisions required before dependent implementation

- Dev 1 and Dev 2: accepted legacy-day interpretation, invalid input behavior,
  supported cache/client versions and observable acceptance fixtures.
- Dev 1 and the schema coordinator: five exact fields above, uniqueness and
  collision handling, migration order, local representation and recovery.
- Dev 1 and sync/data owners: concrete mixed-version cutover, queue ownership,
  offline replay, retry, user-visible blocking and downgrade behavior.
- Dev 4: whether pantry expiry has any future role; no expiry data is removed
  by this proposal.

Record actual decision owners, dates and review evidence once agreed. This
proposal does not complete T001, D1-002 or any migration.
