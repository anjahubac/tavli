# Realtime signal contract for review

Owner: Dev 3. Independent contract reviewer: Dev 1 (confirmed by Matija, 2026-11-23). See the
[experiment and review questions](../research.md) and
[acceptance fixtures](acceptance.md).

## Server to client

| Stream | Record | Recipient | Meaning |
| --- | --- | --- | --- |
| Household | `id`: household UUID, `revision`: positive integer | Authenticated current members of that household | At least one committed shared change is available |
| Personal | `id`: account UUID, `revision`: positive integer | The authenticated owner of that account | Recheck membership, role, and whether the household has at least two members |

Use Postgres Changes on two dedicated revision tables and subscribe to UPDATE
events filtered by scope ID. The Realtime publication emits UPDATE only so
physical deletes cannot reveal scope IDs. The server creates each row before it relies on
an UPDATE signal. Explicit authenticated SELECT grants and RLS enforce the
recipient rules; the client cannot write or publish revisions. The revision
is a wake-up hint. There is no event replay requirement and it is independent
of the downloader's persisted cursor. An event with an invalid shape or
unexpected ID is ignored. A lost signal is handled by catch-up or fallback.

Shared business sources include shopping lists,
items, sources and contributions, pantry items and consumption entries,
meal plans and entries, recipes and recipe versions, household custom foods
and aliases. A household rename notifies each member's personal signal (a row-level
trigger on `households.name`), because the client reads the name with the
membership check, not in the pull.
`supabase/tests/14_household_realtime_test.sql` fails when a public table with a
`household_id` column has no `realtime_update` trigger and is not listed there
with a reason (`household_members` uses personal signals; `deletions` is written
by the delete triggers of the sources). Publish from the transaction that makes the change,
including deletes and writes through RPCs. Off-scope business data and personal
data are outside these streams. Review trigger batching and the cost of
multiple concurrent commits to one household revision row.

## Subscription and scheduling

A signed-in account listens to its own signal. The active household stream
is eligible when membership is verified and the server reports at least two
members. In the same transaction as a membership change, increment the personal
revision for the changed account and for any remaining member affected by
crossing the two-member threshold. On a one-to-two join, increment both the
existing member's revision and the joining member's revision. On a two-to-one
departure, increment the departing and remaining members' revisions. Each
device receives only its own account's notification. Establish
subscriptions and perform a membership check and catch-up on confirmed
connection or reconnect to cover changes during setup. The eligibility RPC takes the expected household UUID and returns true for
two or more members, false for a solo membership, or null when the caller
cannot verify membership in that household.

One scheduler owns pulls for each active account and household. It batches
household signals with a 250 ms quiet period capped at one second of intentional
waiting. If a pull is busy, preserve a pending request and run the follow-up
serially. Transient download failures keep a pull pending, even when both
channels are healthy. Retry from the saved cursors after 5 seconds, 10 seconds
and then every 30 seconds while in the foreground. Membership checks can run
during backoff and discard pending retries if the scope is no longer verified.
Backgrounding pauses the retry timer and foregrounding drains pending work.
A settled pull resets the backoff.
For an unavailable applicable stream, run a check every 15 minutes while
foregrounded. If the membership stream is unavailable, that check includes
membership before a pull. Stop the timer when the stream recovers, on
backgrounding or when the scope ends. An intentionally absent household stream
for a solo household does not start the timer by itself.

On sign-out or a household change, detach old subscriptions, discard scheduled
old-scope work and reject callbacks tagged with the old scope. Preserve the
existing offline outbox and downloader behavior. Old clients continue
syncing through their existing resume flow. This design needs additive server
schema and does not currently require a Drift schema version change. Existing
denied-write recovery remains in place. If a signal is missed, the existing
session check on return to the app, the check on confirmed reconnect, or the
foreground fallback during a known outage can detect the membership change.
A filtered delete that returns zero rows may produce no denied-write error; it
relies on those recovery paths under the current proposal.

## Known limitations and design notes

- **Zero-row delete (RT-08):** accepted for 009, not fixed. See the known gap in
  [spec.md](../spec.md#known-gap-carried-from-the-denied-write-fix).
- **Personal data** (ratings, favorites, taste profiles, allergens) does not
  publish signals. Another device of the same account sees it on resume, reconnect
  or the foreground fallback.
- **Publication is update-only and global:** `alter publication supabase_realtime
  set (publish = 'update')` applies to every table in it. Deleted rows are never
  published because Realtime cannot apply RLS to them, so a delete would reveal
  the former scope ID to any signed-in subscriber. The migration raises if the
  publication already holds tables. Before deploy, confirm it is empty in the hosted
  project. Future realtime features receive UPDATE events only.
- **Visibility:** the app counts as visible unless the lifecycle state is `hidden`
  or `paused`. `inactive` (an unfocused desktop window, Android split screen)
  keeps realtime running.
- **Failed membership check:** the scheduled work stays pending and retries after
  5, 10 and then 30 seconds, instead of waiting for the 15 minute fallback.
