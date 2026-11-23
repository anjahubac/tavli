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
items, sources and contributions, pantry items and consumption entries, and
meal plans and entries. Publish from the transaction that makes the change,
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
serially. Membership checks precede new work for a possibly changed scope.
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
