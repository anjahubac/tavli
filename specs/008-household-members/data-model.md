# Data model: member planning inputs

**Status**: personal storage and advisory resolver implemented on the 008 work branch. Remaining targets follow the
[contract](contracts/member-planning-inputs.md). Allocate migrations with
Dev 1 after reviewing [the slice plan](plan.md).

| Data | Current | Target and invariants |
|---|---|---|
| Personal tastes | Drift `user_profiles(id, profile_json)`; Supabase `taste_profiles(user_id, profile, updated_at)`; user-scoped sync | Keep the existing row/owner. Add typed JSON fields for liked/disliked food IDs, dish-kind wires and reviewed cuisine codes, plus an optional bounded note in a later slice. Missing new fields read as empty; preserve unrelated legacy keys on edits. Resolve conflicts in planning toward dislike for ranking. |
| Sharing | No separate state | Owner-only SQL `user_planning_sharing(user_id, preferences, revision)` with a read grant and writes through the authenticated `set_planning_preferences_sharing` RPC. Missing row means off at revision 0. The RPC compares the expected revision. Consent mutations stay outside the outbox. The later note slice adds its separate flag. |
| Favorite | Ratings are a separate personal entity | Drift v9 and SQL `user_favorites` hold one owner/recipe pair. Active state is a boolean so clearing and adding again use the same outbox identity. A server-issued membership ID scopes that identity and is cached with the account. SQL cascades recipe or membership deletion and syncs tombstones. A new membership has a different ID, so stale outbox writes cannot restore old favorites even after rejoining. |
| Allergen selections | No personal relation | Drift v8 `user_allergen_selections(user_id, group_codes_json)` and owner-only SQL `user_allergen_selections(user_id, group_codes, updated_at)` store one validated set per account. A full replacement, including an empty list, is one outbox upsert. SQL migration `20261121173000_user_allergen_selections.sql` enforces the catalog codes. This keeps a selection atomic across retries and allows account deletion to cascade. An empty selection contributes zero codes and requires no additional confirmation record. The owner settings path may read and modify the owner's own choices. Only the server planner reads participant selections for planning, with verified membership. No participant selection data in member aggregates, client plan responses or AI payloads. |
| Catalog mapping | Reviewed identity and matching are separate catalog work | `food_allergen_groups(food_id, group_code)` plus an agreed representation of mapping completeness. An empty relation alone cannot distinguish a reviewed mapping with no matching groups from an unknown one. Metadata describes the food; it carries no association with a member. |
| Planning aggregate | No persisted aggregate or server resolver | Private SQL reads current membership and consent to derive preferences and visible favorites. Catalog food IDs are accepted only from a trusted server allowlist. The allergen union uses a separate private function. Return the allowlisted aggregate without person identifiers, raw personal rows or allergen data. Start with fresh authorized reads and no persisted aggregate. Any later offline cache and queued requests need explicit account/household scope and invalidation. |

## Compatibility and lifecycle

- Reuse the existing account partitioning and transactional outbox for synced
  personal writes. Ordinary sign-out retains the account's cache; account
  deletion purges owned records. Verify fresh/upgrade caches and pending writes
  before enabling new entities. For the dish-kind JSON slice, only the stored
  JSON and existing sync payload change; the SQL and Drift schemas stay intact.
- Deploy the additive SQL migrations before distributing the client that syncs
  these rows. A cached account without a favorite membership ID can still read
  already downloaded favorites. Its first edit refreshes that ID online; later
  edits can queue offline under the same membership. Keep the newer client on
  devices with pending writes for the new sync entities until they upload.
- Additive SQL slices need explicit authenticated grants, RLS and local pgTAP
  tests. A server-side function verifies requester/membership before reading
  peer data. Include allowed operations alongside denial tests and cover
  account/recipe deletion and membership transitions.
- For new Drift entities, coordinate schema version, generator output, sync
  registry and deletion handling. Specify minimum compatible client behavior
  and forward recovery in each migration PR. No data reset is required by this
  proposal.
