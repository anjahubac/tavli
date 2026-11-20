# Calendar-date cutover proposal

**Status:** Implemented as the additive migration `20261120120000_calendar_dates.sql`
and the date-only sync writer (see Implemented cutover). The sections before it
record the evidence the decision was based on.
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

## Implemented cutover

Decision (20 Nov 2026, Dev 1 with Dev 3's review on #31): keep it simple and
do not reset any database. The team environment holds no calendar data that
needs special handling, and the conversion below preserves any rows that do
exist.

- **Server.** A new migration changes the five columns to `date` with
  `(column at time zone 'UTC')::date`. Existing rows keep their UTC day, which
  is how the app always wrote them, independent of the session time zone
  (checked under `Europe/Belgrade`, including both DST change days). If two
  lists of one plan fell on the same day, the existing unique constraint stops
  the migration instead of merging them silently.
- **New app.** The sync writer sends the five fields as `YYYY-MM-DD`. The
  reader already accepts both forms (#42), so downloads are unchanged.
- **Older app and queued writes.** An older build, or an outbox entry queued
  before the update, still sends a UTC-midnight timestamp. PostgreSQL stores
  it in a `date` column as the same day, so no write is rejected and no
  blocking step or forced update is needed.
- **Local cache.** drift keeps `DateTime` at UTC midnight; no local schema
  version or upgrade step is added.
- **Unchanged.** `created_at`, `updated_at` and other instants stay
  `timestamptz`. Pantry expiry is out of scope.

Tests: `supabase/tests/09_calendar_dates_test.sql` covers the five column
types, date-only and legacy timestamp input for every field, the period
checks, one list per plan and week across old and new formats, and rejection
of a non-existent date. `test/sync/entities_test.dart` checks the
`YYYY-MM-DD` wire format and null periods.

Forward recovery is a new additive migration; the applied one is never
edited. Hosted deployment stays with the team's CI.
