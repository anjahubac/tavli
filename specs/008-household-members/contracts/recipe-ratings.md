# Recipe ratings contract

**Status:** proposed for review  
**Owner:** Dev 3  
**Producer:** personal rating repository and household summary endpoint  
**Consumer:** recipe detail and recipe list UI  
**Source:** D3-018 / FR-011, Trello “Ocene recepata”

## Purpose

Let a member keep a current rating for each saved recipe and let members see a
small household summary without exposing each other's personal feedback.

## Write model

- A rating belongs to exactly one authenticated user and one saved recipe.
- There is at most one current row for `(user_id, recipe_id)`. Re-rating or
  cooking again updates that row; it does not add another vote.
- `stars` is an integer from 1 through 5.
- The existing `comment` column is an optional **private note about the rating**.
  It is never a recipe comment and is never returned by a household summary.
- Writes use the existing account-scoped offline cache and outbox. IDs and
  conflicts must preserve one row per user and recipe across devices.
- Removing a recipe removes its rating and any summary cache for that recipe.

## Read model and privacy

- The owner can read and edit their own stars and note.
- A current member of the recipe's household may read only the aggregate
  `average_stars` and `rating_count` for that recipe.
- The aggregate is calculated server-side. No endpoint or view returns another
  member's ID, individual stars, note, or timestamps.
- Membership is checked on every summary read. A non-member receives no row.
- The local UI reads the cached summary from Drift. A data-layer refresh may
  update that cache; network access does not happen in widgets.
- Offline use shows the last cached aggregate. When no cached/current ratings
  exist, the consumer shows no numeric summary.

## UI handoff

The future UI offers an explicit “Oceni” action alongside the future favorite
action. It can reveal a small inline/dropdown star selector headed “Da li ti se
svidelo?” after cooking; it must not use a blocking popup or repeatedly prompt.
The visual layout and when an inline suggestion appears remain for the UI design
slice. The recipe detail and list show household average and count. Personal
notes are accessible only to their author.

## Compatibility and failure behavior

- Preserve existing rows by retaining the latest row when consolidating any
  duplicates for the same user and recipe; older rows are removed through the
  normal deletion/tombstone path.
- Invalid stars and writes for a recipe outside the caller's household are
  rejected by server constraints/RLS.
- Offline writes remain queued and are retried by the existing sync engine.
- A failed aggregate refresh keeps the last local summary and does not block
  recipe or rating writes.

## Acceptance evidence

- Two accounts in one household cannot read each other's rating row or note.
- Both accounts can read only the summary; a non-member cannot read it.
- Repeated writes from one account update one rating and do not increase the
  rating count.
- A member's update changes the aggregate; deleting the recipe removes rating
  data and its local summary.
- Summary refresh failures preserve the offline cache.
