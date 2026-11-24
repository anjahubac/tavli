# Gateway quota data model

The server model is already merged in [PR #124](https://github.com/anjahubac/tavli/pull/124).
The Flutter quota-pause table below is proposed for the client slice.

| Store | Existing state | Target |
| --- | --- | --- |
| Postgres `ai_calls` | One `text` or `vision` provider attempt per row, with caller ID and start/finish timestamps | Edge Function uses the existing `ai_reserve` and `ai_release` RPCs |
| Drift `ModelStatuses` | Per-model and credential cooldown/usage | Preserve current rows and semantics |
| Drift gateway pauses | No stored gateway quota pause | One row per `(account_id, scope)` with `until_at` |

Scopes are `text`, `vision` and `all`. Daily quotas pause one kind. Minute,
concurrency and global quotas pause both kinds through `all`. Before a shared
attempt, use the later of the relevant kind and `all` deadlines. When writing
a pause, keep the later deadline so older concurrent responses cannot shorten
it. Expired rows have no effect and can be pruned. BYOK bypasses this state.

The table is device-only and has no outbox, sync registration, or server
counterpart. Sign-out retains its rows and a different account reads only its
own. Device cache deletion for an account removes that account's pause rows.
Persist timestamps as absolute instants. The table stores no token, provider
credential, prompt, photo or response.

Allocate the drift schema version with Dev 1 during integration. Add the table
on fresh install and on upgrade without rewriting recipes, model statuses or
outbox rows. Test startup, upgrade, restart, account switch and concurrent
updates for the same scope. The server slice requires no new migration.
