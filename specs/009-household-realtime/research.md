# Local Realtime experiment

Run on 2026-11-23 against repository baseline `6297407` and Supabase Realtime
`v2.156.2` in an isolated local stack with Tavli migrations. Three synthetic
accounts used the local Auth, REST and Realtime endpoints: owner, member and
outsider. All clients addressed the same household signal, including the
outsider as a negative control.

The temporary fixture published two tables keyed by household and user. Each
stored only its scope ID and revision. Database triggers incremented revisions
after business or membership changes. Clients subscribed only to updates.
The household read policy checked current membership. The account read policy
checked that the authenticated user owned the row. Clients had SELECT grants
on the signal tables. The existing member removal RPC was used as the owner.

| Case | Observed result |
| --- | --- |
| Eight shopping edits | 359–527 ms from starting the write to reading the checked state on the second client, including signal delivery |
| One write affecting 24 shopping rows | All 24 signals arrived within 536 ms from the start of the write |
| Shopping item deletion | The household revision changed and the next read no longer returned the item |
| Edit while disconnected | A new subscription followed by a REST read using the previous row timestamp recovered the edit in 25 ms from the start of reconnect |
| Membership removal | The removed user received their own revision change and read their new membership. The owner received the next old-household signal. The removed user received zero such signals on the still-open connection during the following 1.5 seconds |
| Unrelated account | Zero events during the run. REST reads returned no matching household signal or shopping item |

These timings apply to loopback and the synthetic shopping fixture. The experiment
did not exercise the Flutter client, its full cursor and outbox paths, a multi-user
load profile, or device and hosted network latency. Pantry and plan delivery and
the one-to-two member transition remain acceptance cases.

## Original Q1 proposal

The [current contract](contracts/signals.md) supersedes the original member-count threshold and outage-only polling below.

Use Postgres Changes for updates on the two revision tables. Keep payloads to the
scope ID and revision. A household subscription is eligible with at least two
members. Keep the own-account subscription while signed in so it can signal
membership transitions, including the first join into a household and the
one-to-two member transition for an existing member. Determine eligibility from
the server before subscribing to household changes. Review how to notify both
affected accounts during a member-count threshold crossing.

For shared data, start with a 250 ms trailing debounce capped at one second
from the first pending signal. A signal during a pull marks the scope dirty so
a follow-up pull can cover it. On confirmed resubscription, schedule a cursor
pull immediately after checking membership. Use the SDK's reconnect behavior
and prevent duplicate app retries. If separate retries are needed, review
measured behavior before choosing a backoff schedule. Treat five seconds from a
committed edit or a confirmed reconnect to a refreshed second client as the
initial acceptance target for the local two-client journey. Keep the existing 15-minute resume threshold. Matija also approved a pull every
15 minutes while the app is in the foreground and the applicable Realtime
subscription is unavailable. Schedule that fallback for the current signed-in
scope only. Cancel it when the subscription is healthy, the app leaves the
foreground, or the account changes. A solo household with a healthy personal
subscription does not count as a failed household subscription.

The experiment informed Q1. Matija confirmed Dev 1 review on 2026-11-23.
See [the signal contract](contracts/signals.md) and [acceptance fixtures](contracts/acceptance.md). Keep denied-write
membership recovery where present and review the zero-row DELETE case with the
membership contract. No rollout or hosted authorization behavior was tested.


## Questions for Dev 1

This is a design review before implementation. Tavli's existing sync engine,
downloader, outbox, and membership check are the integration points. The
Realtime subscriptions, revision signals, pull scheduling, and foreground
fallback below are proposed behavior. The local experiment used temporary
fixtures outside the app. Review whether the proposed integration is sound
and whether the acceptance cases would prove it.

1. **Pull during an existing pull.** Can a signal arrive after the downloader
   has already passed the changed table? Review the proposed pending follow-up
   against `SyncEngine.pull()`, which currently returns if a pull is running.
   The acceptance case sends a change at that point and verifies that the
   receiver eventually sees it, with at most one pull running at a time.
2. **Pending writes and deletion.** Review the existing ordering of uploads,
   incremental reads, and deletion records. In the acceptance case, one client
   checks an item while the other has an unrelated offline edit waiting to send.
   After reconnect, both changes must converge. Repeat with a server deletion
   and confirm that a duplicate signal or upload retry does not bring the
   deleted item back.
3. **Complete coverage of shared changes.** Verify the list of source tables
   with the shopping, pantry and plan owners. Include indirect writes such as
   derived shopping rows and changes made through RPCs. Check that triggers
   publish a committed change, including deletion, and that advancing a
   household's single revision row adds acceptable contention during batches.
4. **Membership and isolation.** Check how the server wakes both affected
   accounts when membership crosses one or two members, including the existing
   member whose own role and household ID might stay the same. Confirm that a
   failed membership check stays retryable and that callbacks from an old
   account or household cannot trigger work in the new scope. Check whether a
   zero-row delete needs its own recovery path when the membership signal
   is missed.
5. **Reconnect and fallback.** Review when a recovered subscription schedules
   the cursor pull and how the foreground fallback shares that scheduler.
   Confirm that an edit sent during the gap before resubscription arrives in
   the next pull, and that reconnect and the fallback do not start competing
   pulls.


## Local implementation evidence

The isolated stack applied the implementation migration. The complete pgTAP
suite passed 649 assertions. A three-client loopback check against the actual
migration measured eight shopping edit-to-read runs at 412–1,027 ms and a
single household signal for a 24-row update at 503 ms. After reconnection a
client read its missed update in 401 ms. The removed member received its
personal signal, and neither it nor the outsider received the next household
update. A Dart smoke probe using `SupabaseSyncSignals` confirmed the eligibility
RPC, replication-ready callback and delivery of an UPDATE revision.

These results cover local database and adapter behavior. Timing on two
physical phones and deployment on hosted environments have not been verified.
