# Contract: Shopping food identity and catalog entry

**Status**: Draft for Dev 4 review; not accepted
**Spec**: [020 catalog shopping](../spec.md), FR-002 / FR-003; Trello #25 / #26
**Producer / consumer / reviewer**: 018 ingredient catalog / 020 shopping / Dev 4

## Scope and existing behavior

This proposal covers catalog identity in shopping aggregation and adding a
manual item from the catalog. It does not authorize the shopping code split,
pantry deduction, kitchen-measure conversion, or a catalog matching service.

Current recipe ingredients can carry an optional `IngredientLink` with
`foodId`, `matchedKey` and `linkSource`. `ShoppingItems` has no `foodId`; recipe
demand and existing rows are reconciled by normalized text and unit group.
Manual entry stores its text, quantity and unit without resolving it against the
catalog. The accepted catalog model uses stable text IDs and keeps shared and
household foods in the same `foods` table.

## Proposed interface

### Persisted identity

Add a nullable `food_id text` to local `shopping_items` and server
`public.shopping_items`. It references `public.foods(id)` and uses `ON DELETE
SET NULL` so removing a household food cannot remove a shopping row or its
original text. A null ID means the row has no confirmed catalog identity; it
does not mean “look this name up automatically.”

The application representation is:

```dart
sealed class ShoppingFoodIdentity {
  const ShoppingFoodIdentity();
}

final class CatalogFoodIdentity extends ShoppingFoodIdentity {
  const CatalogFoodIdentity(this.foodId);
  final String foodId; // stable foods.id; never derived from a name

  @override
  bool operator ==(Object other) =>
      other is CatalogFoodIdentity && other.foodId == foodId;
  @override
  int get hashCode => Object.hash(CatalogFoodIdentity, foodId);
}

final class UnlinkedTextIdentity extends ShoppingFoodIdentity {
  const UnlinkedTextIdentity(this.normalizedName);
  final String normalizedName; // ingredientKey(original name)

  @override
  bool operator ==(Object other) =>
      other is UnlinkedTextIdentity && other.normalizedName == normalizedName;
  @override
  int get hashCode => Object.hash(UnlinkedTextIdentity, normalizedName);
}
```

The row's existing `name` remains the display/source text. Do not replace recipe
ingredient text or free text with a canonical name when linking. For a catalog
group, show the catalog's current name; retain each member row's original name
and source details for review.

### Identity creation and validation

- Recipe demand uses `foodId` only when the existing ingredient link is valid:
  its `matchedKey` still matches `ingredientKey(name)`, and the food is active
  and visible in the current household. A missing, stale, withdrawn or
  inaccessible link falls back to `UnlinkedTextIdentity`; it is never repaired
  by matching text during shopping sync.
- A manual catalog item receives `foodId` only after the user selects a
  currently visible catalog result. Saving typed text, even an exact catalog
  name, keeps `foodId == null`.
- A valid food must be shared or owned by the active household. Enforce that
  rule on the server write path as well as in the client; a household member
  must not be able to attach another household's private food by supplying its
  ID.
- Existing shopping rows migrate with `food_id == null`. Do not backfill by
  name or fuzzy match. A later explicit resolution flow is a separate task.

### Grouping and quantity

The proposed display key is the typed pair
`(ShoppingFoodIdentity, unitGroup)`, not a concatenated display-name string.
For unlinked text, `unitGroup` comes from the current canonical unit resolver;
unknown units retain their own normalized/raw group. For catalog foods,
compatible quantities aggregate only when they can be expressed in the same
base unit under the accepted unit contract.

- Exact supported conversions keep using integer micros and the current
  `normalizeUnit` ratios. Approximate status on any included contribution stays
  visible on the aggregate.
- Unknown quantity and unsupported units never add to a known numeric total;
  keep them visible with the existing “Proveri količinu” behavior.
- Do not use kitchen-measure or ingredient-density conversions in this slice.
  Those remain gated by Q1 in spec 017 and the catalog-specific conversion
  decisions in spec 018.
- Equal text with different identities remains separate. In particular, a
  50 g unlinked “pavlaka” row does not join a catalog-linked “pavlaka” group.

Grouping is a read/display projection. It must not destructively merge or
delete the underlying shopping rows, source links, contributions, allocations,
purchase provenance or outbox records. Each displayed aggregate retains the
IDs of its member rows so that item actions can target the original records.
The exact bought/unbought behavior for an aggregate containing both generated
and manual rows needs Dev 4's acceptance before the UI task starts.

### Manual catalog addition

The catalog picker is scoped to shared foods plus foods owned by the active
household, using the existing cached catalog. Selecting a result stores its
`foodId` and the user's entered amount/unit. Typing text and saving without
selection follows the existing `addManual` path and stores no identity. A
catalog load failure remains a recoverable error; it must not silently turn a
typed entry into a catalog match. Offline behavior uses cached results; if the
selected food is unavailable or no cached result exists, preserve the text and
offer the existing free-text path.

## State, migration and compatibility

The new local value and its existing shopping-row write must be committed in
the same database transaction and use the existing household-scoped outbox.
Retries must be idempotent by the existing shopping-item ID. Deletion of an
underlying catalog food clears the optional link and preserves the row text.

The server migration is additive: nullable `food_id`, a foreign key to `foods`,
and a validation trigger/policy for active shared or same-household foods. It
must preserve existing RLS behavior and not cascade-delete shopping rows. Add
two-household SQL tests for valid shared/same-household links and a denied
cross-household link.

Old clients do not know `food_id`. The current sync path batches rows through
`SupabaseSyncRemote` and calls the locked `postgrest` 2.9.1 `.upsert` with
`onConflict: id`, `ignoreDuplicates: false`, and its default `defaultToNull`.
The [Supabase Dart upsert reference](https://supabase.com/docs/reference/dart/upsert)
says missing-field defaults apply on insert, not when merging with an existing
row. That is evidence that an old client's payload omitting `food_id` should
preserve an existing link on conflict and insert a new legacy row as unlinked.
Add a compatibility regression case against the actual sync/PostgREST path
before rollout; if that check disagrees, gate the feature or document downgrade
to unlinked text. Allocate the local schema version after preceding migrations
have merged.

## Acceptance fixtures

Use the synthetic fixtures already recorded in [spec 020](../spec.md) and
merged test PRs #112 and #113 as starting cases; convert them from prototypes
to regular regression tests with the implementation.

1. Three recipe ingredients with one valid food ID and quantities 200 g, 100 g
   and 0.2 kg display as one 500 g group in both shopping modes.
2. A 75 g unlinked row with the same text stays separate from that linked group.
3. A 200 g recipe row and a 100 g explicitly selected manual catalog item with
   the same food ID display as 300 g, retaining both underlying row IDs and
   provenance. Deleting/reconciling either member does not erase the other.
4. A 50 g typed free-text item remains unlinked and separate even when its text
   exactly matches the selected food's name.
5. Reopening the app and replaying a pending outbox operation preserves the
   explicit identity exactly once; legacy rows remain unlinked. An old-client
   upsert without `food_id` preserves an existing link and creates a new row
   without one.
6. A stale recipe link, withdrawn food or foreign-household ID cannot form a
   catalog group. Original text remains visible.
7. Unknown amounts, unsupported units and approximate inputs retain the
   behaviors above; no unsupported conversion is guessed.
8. Empty catalog, cached offline selection, catalog read failure, retry and
   cancellation do not create an unintended linked item.

## Decisions for review

| Decision | Proposal | Owner / reviewer | Status |
| --- | --- | --- | --- |
| Identity and free text | Stable `foods.id`; explicit selection only; no automatic legacy backfill | Dev 1 / Dev 4 | Open |
| Aggregate action semantics | Keep source rows; confirm whether a group action toggles every member or opens row-level actions | Dev 4 | Open |
| Mixed client versions | SDK docs indicate omitted fields do not replace existing values on conflict; add a sync/PostgREST regression case before rollout | Dev 1 / Dev 4 | Proposed; test outstanding |
| Unit groups and precision | Exact current conversions only; no kitchen/density guesses | Dev 1 / Dev 2 | Open |
| Catalog ownership validation | Shared or active-household food only; deny cross-household IDs in SQL tests | Dev 1 / Dev 3 | Open |
| Manual quantity display | Preserve entered quantity/unit; confirm display when the same food has mixed exact units | Dev 1 / Dev 4 | Open |

This is a proposal, not implementation approval. Keep T001 unchecked until the
owners record accepted decisions and link the reviewed fixtures here.
