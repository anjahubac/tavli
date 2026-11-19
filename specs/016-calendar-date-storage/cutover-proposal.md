# Calendar-date cutover proposal

**Status:** Draft for review; not an approved migration or implemented fix.
**Source:** D1-002 / FR-001 in [016](spec.md), Trello card
[Datumi bez vremenske zone](https://trello.com/c/HLtlyVWL/16-datumi-bez-vremenske-zone).
**Owner:** Dev 1. **Proposed independent reviewer:** Dev 2, with affected data
owners reviewing migration and sync behavior.

## Existing representation

On team `dev` as of 18 Nov 2026, the intended calendar-day columns are:

| Logical value | Server column / type | Local drift column |
| --- | --- | --- |
| Plan start and end | `meal_plans.start_date`, `end_date`: `timestamptz`, required | `startDate`, `endDate`: `DateTime`, required |
| Meal day | `meal_plan_entries.date`: `timestamptz`, required | `date`: `DateTime`, required |
| Shopping period | `shopping_lists.period_start`, `period_end`: nullable `timestamptz`, both present or both absent | `periodStart`, `periodEnd`: nullable `DateTime` |

The repository creates intended calendar values as UTC midnight using
`CivilDate.toWire()`. The sync entity sends UTC timestamps; since #42 its
reader also accepts date-only values (see Compatibility evidence), and
consumers interpret calendar fields using `CivilDate.fromWire()`. Local schema
version is 5 at this baseline.
`created_at` and other event times are instants and are outside this change.
Pantry expiry is excluded pending its separate product decision.

The shopping period has ordering and uniqueness constraints; a future
conversion needs to detect and resolve any collision before changing them.
Changing a type alone does not prove existing historical values all followed
the intended UTC-midnight convention. The source time zone of exceptional
legacy timestamps may not be recoverable from the timestamp alone.

## Compatibility evidence

The [synthetic fixture](fixtures/civil_date_wire.dart.txt) exercises the team
sync entities with both timestamp and date-only input, year boundaries, DST
dates, null shopping periods and invalid calendar input (nine cases). It is a
manually invoked check and is not part of the normal test suite.

Before the reader change in #42 (merged 18 Nov 2026), five of the nine cases
failed under `Europe/Belgrade`: for example `2026-12-31` was read as
`2026-12-30`, and an invalid date was normalized instead of rejected. The
inputs were synthetic. The server columns still use timestamps, so this never
showed that hosted rows return date-only values or that existing dates are
wrong.

On current `dev`, which includes #42, all nine cases pass under both
`Europe/Belgrade` and `America/Los_Angeles`. To reproduce, from a `dev`
checkout with dependencies installed:

```sh
cp specs/016-calendar-date-storage/fixtures/civil_date_wire.dart.txt /tmp/tavli-civil-date-wire-test.dart
TZ=Europe/Belgrade flutter test --no-pub /tmp/tavli-civil-date-wire-test.dart --reporter expanded
TZ=America/Los_Angeles flutter test --no-pub /tmp/tavli-civil-date-wire-test.dart --reporter expanded
```

#42 also asserts exact UTC-midnight storage after a Drift round trip for plan
dates and shopping periods.

The fixture already assumes one reading of legacy timestamps: the UTC day of
the instant (for example `2027-01-01T00:00:00+01:00` is `2026-12-31`). Step 1
below still has to agree what legacy values mean, so until then this is an
assumption of the fixture, not a decision.

## What is still unverified

The fixture verifies reading only. Before converting columns, rehearse on a
disposable database with synthetic records. Include two legacy shopping lists
for the same plan with different UTC times on the same UTC day. The current
timestamp constraint permits these, but a date constraint would treat them as
duplicates. The preflight must identify that case before any schema change.
Include an offset timestamp whose local date differs from its UTC date,
a standalone list with null bounds, and a queued write from an older client.
Record which writes are permitted during rollout and how queued changes are
replayed before accepting the server migration.

## Shopping-period SQL rehearsal

The [synthetic SQL fixture](fixtures/shopping_period_cutover.sql) reproduces
the shopping period check and uniqueness constraints on a temporary table.
The preflight groups by plan and explicit UTC day. Two distinct timestamps
for one plan project to `2026-12-31`; a different plan on that day and
standalone lists with null bounds do not collide. PostgreSQL rejects the
attempted conversion under the existing unique constraint. The clean
control then verifies the UTC date boundaries, unchanged event timestamp,
null periods and rejection of reversed dates.

The fixture passed on embedded PostgreSQL 18.6 (PGlite 0.5.16) in the Belgrade
and Los Angeles session time zones. To repeat it on a disposable local
PostgreSQL instance already selected in your shell, run:

```sh
PGTZ=Europe/Belgrade psql -X -v ON_ERROR_STOP=1 -f specs/016-calendar-date-storage/fixtures/shopping_period_cutover.sql
PGTZ=America/Los_Angeles psql -X -v ON_ERROR_STOP=1 -f specs/016-calendar-date-storage/fixtures/shopping_period_cutover.sql
```

A passing run reaches `ROLLBACK`. This checks the conversion mechanics on
synthetic data. The Supabase migration chain, access rules and queued client
writes still require local integration tests after the cutover is agreed.

## Proposed sequence for review

1. Agree the meaning of existing timestamp values and how to handle exceptional
   non-midnight values. Define a privacy-preserving, non-production validation
   of conversion collisions and ambiguous records; do not infer original device
   zones from timestamps.
2. A compatible reader for both old timestamps and valid date-only values is in
   `dev` (#42), preserving event timestamps. Still to cover: old cache
   upgrades, the supported client/platform matrix, and the cases above on
   real stored data. This prepares a client; it does not authorize a server
   type change.
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

Status (18 Nov 2026): the schema coordinator replied that she cannot confirm
that `tavli-dev` has no affected calendar data without checking it. If the
check shows nothing to keep, the fresh-database option replaces the migration
path for `tavli-dev`. The check, to be run by someone with access to that
project:

- row counts of `meal_plans`, `meal_plan_entries` and `shopping_lists`, and
  whether any of them belong to people who need the data;
- whether any installed client can still hold queued writes in its outbox
  (the team builds that were used against `tavli-dev`);
- the same counts for any other shared environment before it is reset.

The compatibility reader is merged (#42), including equality with the
UTC-midnight values used for shopping week lookups. The server-side slice
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
