# Realtime acceptance fixtures

Status: behavior accepted by Matija and contract review confirmed on 2026-11-23.
See [local implementation evidence](../research.md#local-implementation-evidence). Run deterministic Flutter tests with fake transport and
clock. Run SQL and wire checks only against an isolated local Supabase project
with synthetic accounts. Devices A and B use separate databases and accounts
in household H. Account C is outside H unless a fixture says otherwise.

| ID | Setup and action | Observable outcome | Test boundary |
| --- | --- | --- | --- |
| RT-01 | A commits a shopping checkbox change with B subscribed. Repeat for a pantry edit, plan entry edit, and an indirect write from a server operation in each applicable flow. | B reads the committed state in its local cache. The local two-client journey targets five seconds from commit. C receives no household event. A rolled-back write emits no signal. | Local Realtime and repository/sync |
| RT-02 | Deliver duplicate, out-of-order and continuous signals with a fake clock. Pause B's pull after it reads shopping, then commit another shopping edit. Deliver its signal before resuming the pull. | Signals use the 250 ms quiet window with a one-second maximum batching wait. No parallel pulls occur. A follow-up covers the edit missed by the first pull. | Flutter sync |
| RT-03 | B edits the quantity of bread offline while A checks milk. Reconnect A and B in both orders, replay an acknowledged write, and repeat with a server deletion and duplicate signals. | Both clients and server converge; independent edits survive, no duplicate logical rows appear and the deleted item stays deleted. Verify pending outbox state and the deletion cursor. | Two-client repository/sync and local backend |
| RT-04 | B disconnects with a saved cursor. A commits an edit before B's restored subscription is confirmed. Trigger the fallback while reconnect catch-up is being scheduled. | B checks membership, pulls from the saved cursor without waiting for a signal, sees the missed edit and runs at most one pull at a time. | Flutter sync and local Realtime |
| RT-05 | A starts alone, B joins H, and later B leaves or A removes B. Also exercise ownership transfer and a switch to another account. Deliver a stale callback after the switch. | Both accounts recheck at the one-to-two boundary; household channels enable at two and disable below two. B can still read the personal removal signal. The old channel delivers nothing to B after removal, with A as a positive control. Old callbacks cannot write to the active cache or schedule work for it. | Local SQL, local Realtime and Flutter auth/sync |
| RT-06 | Keep the app foregrounded with the applicable Realtime subscription unavailable. Advance the clock 15 minutes, then recover, background or sign out. Repeat with a healthy personal subscription in a solo household. | Fallback checks for changes every 15 minutes during the foreground outage. It stops on recovery, background or sign-out. A healthy solo account does not start a fallback for an intentionally absent household channel. Existing resume behavior remains covered. | Flutter sync |
| RT-07 | C tries reading both signal scopes and writing revisions. A also tries client writes to its own revision. Remove B while its connection stays open. | Neither C nor B can receive or read unauthorized household updates. Each user can read their own account signal only. Signed-in and anonymous clients cannot modify revisions. Server writes and authorized reads remain functional. | Local SQL and Realtime |
| RT-08 | Drop B's membership signal. Exercise a reconnect or fallback after removal and the existing denied-write recovery where available. | B eventually rechecks membership and stops work in the old scope. Confirm the correct behavior for a zero-row delete with the reviewer before finalizing the negative fixture. | Flutter auth/sync and local backend |

## Existing regression suites

Use `test/sync/sync_engine_test.dart` for timer, serialization and resume
behavior, `test/sync/downloader_test.dart` for cursor and deletion behavior,
`test/sync/shopping_week_conflict_test.dart` and
`test/sync/shopping_offline_replay_test.dart` for the two-client and replay
setup, and `test/account/auth_controller_test.dart` for session transitions.
The SQL member removal suite provides the allowed case for the removal RPC.
These suites establish baseline behavior; RT-01 through RT-08 still require
feature evidence. The local Realtime experiment covers only part of that matrix.
