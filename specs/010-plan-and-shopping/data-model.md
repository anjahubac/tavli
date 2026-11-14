# Data model: planned additions, not current schema

> Direction review, 2026-11-13: read the [current direction overlay](current-direction.md)
> before new work. This document retains the original 010 scope and acceptance
> history; implemented code and unchecked acceptance must be assessed separately.


**Status:** design for future implementation. No tables/columns/migrations are
created by this documentation change. Keep current rows/ids and applied SQL.

## Existing foundations and additions

| Entity | Existing | Planned addition |
| --- | --- | --- |
| MealPlan | household, start/end, meal types, use pantry | defaultServings for setup; no private profile dump |
| MealPlanEntry | plan/date/type/recipe, locked/cooked | resolved servings and approved recipeSnapshotJson |
| ShoppingList | household, optional plan and week | periodStart/periodEnd civil dates; week supports 1–6 |
| ShoppingItem | ingredient/quantity/unit/category, bought/manual, recipe ids | retain immutable bought facts and independent manual rows; provenance comes from contributions; purchaseProvenanceJson freezes source labels at purchase |
| PantryItem | quantity/unit/category, added/expiry | confirmedAt and nullable unique sourceShoppingItemId for a purchase receipt |
| UserProfile/Rating | own-user JSON/ratings/favorite | use existing personal entities; define typed profile parsing, no new shared preference store |

Plan default/per-entry servings are integers 1–20, matching existing recipe
creation limits. New-plan defaults: lunch and two servings or a selected plan's
value. Household-level defaults remain future work; there is no current size field.

Calendar values are year/month/day. Wire them as UTC-midnight encodings of the
same civil date in existing timestamp columns; decode calendar fields without
applying device-timezone conversion. Ordinary event timestamps remain instants.
Week periods are plan range ∩ Monday–Sunday. A month can touch six periods.
Each plan has one canonical list per period; the whole-plan view aggregates them.
Aggregate actions operate on underlying weekly ids atomically; they do not
create month-level purchase records. Mixed purchased/outstanding groups retain
their per-week facts and show remaining quantities.

Multiple plans are retained. The UI selects one; default to newest created plan
containing today, otherwise most recently created. No global single-active-plan
flag or household schema expansion is needed.

## Approved meal snapshot

Snapshot contains recipe title, base servings, ingredient names/quantities/units/
categories/notes, known preparation time and available steps. The entry stores
resolved servings separately; quantities scale by entry/base servings. Source
recipeId is optional and may become null on deletion; snapshot remains.

Unclassified photo paths are optional provenance, not proof of a finished-dish
photo. Missing/deleted media uses the neutral fallback; text/ingredients/steps
must remain. This feature does not add a second recipe-photo storage pipeline.

Snapshots may initially be summaries without steps. Approved step completion
updates only that snapshot; any proposed ingredient/portion change must be
reviewed and reconciled as a normal plan change. Existing library version/undo
semantics are preserved independently.

## New ShoppingSource (shopping_sources)

- UUID, householdId, listId and kind (planEntry or recipePreparation).
- A plan source links a planEntryId and reads its approved snapshot/servings.
  A standalone source has no plan entry; it owns a frozen recipeSnapshotJson,
  resolved servings, stable preparation id and optional library recipeId.
- Unique plan-entry source within its canonical week; standalone sources keep
  the same preparation id for repeated adds/changes. Explicit "Ponovi nabavku"
  makes a new preparation; names alone do not identify a source.
- Use an existing open preparation for the same library recipe/draft origin;
  correcting "imam" never starts a new preparation automatically. An explicit
  repeat supersedes the current source for new additions but retains history.
- Unsaved generated/imported drafts have a stable in-session origin id; only
  shopping approval persists a snapshot. Never invent a saved recipe/meal plan
  or persist temporary photo-file references as part of this action.
- Plan sources live in canonical weekly lists; standalone sources use the
  household's recipe-shopping list with no mealPlanId. A plan/recipe mode view
  filters by source, not by fake calendar entries.
- Household-matching FKs and kind-specific nullability checks apply. User
  supplies a separate-preparation intent if a library recipe is already planned;
  viewing the planned context reuses that entry source.
- Closed demand (cooked/explicitly removed) does not create new outstanding
  shopping. Closing cooked demand retains its supply allocations for stock
  review; do not make possibly consumed stock available again automatically.
  Removing an uncooked future meal releases its unused reservations. Explicit
  repeat changes the current preparation pointer, not earlier purchase history.

## New ShoppingContribution (shopping_contributions)

- Client-generated UUID; householdId, shoppingItemId, shoppingSourceId.
- Stable ingredient identity, unit dimension/base unit, scaled quantity (nullable
  only for an explicitly unknown amount), original display unit/notes.
- One row per source + ingredient identity + compatible unit group; duplicate
  lines within that preparation combine only when safely comparable.
- Household-matching foreign keys to the shopping item and source; unique source
  identity makes repeated reconciliation an update, not an insertion.

Normalize case, trim and collapse whitespace. Preserve meaningful ingredient
differences; do not use AI guesses, synonyms or diacritic folding to merge stock.
Convert only g↔kg and ml↔l; count units combine with the same count unit. Other
units combine only when identical. Never infer density or tablespoon equivalents.
Use fixed precision of six decimal places before comparisons and display with
existing Serbian quantity formatting. Reject negative/nonfinite confirmed values.

Manual shopping rows remain independent even if their names match generated
rows. Existing fromRecipeIds can remain a display/backward-compatibility hint;
it is never the authoritative occurrence/quantity ledger.

## New SupplyAllocation (supply_allocations)

- Client-generated UUID; householdId, contributionId.
- Exactly one origin: pantryItemId or purchasedShoppingItemId.
- Confirmed quantity in the contribution's base unit; for unknown amounts an
  explicit coversWholeUnknown flag applies to that contribution only.
- Unique contribution + canonical supply identity; no overlapping duplicate credit.
- Matching-household FKs; purchase origins must be bought, same ingredient/unit.

Allocate confirmed supply in chronological meal order, then meal type and entry
id for deterministic ties, across all outstanding reservations in the household.
Read current capacities/allocations and write changes in the same local transaction.
An unconfirmed/expired/unknown pantry quantity cannot supply a guessed numeric amount.

A pantry receipt with sourceShoppingItemId points to the **same** supply as
that bought item. Its canonical identity is the purchase id; allocations from
either view consume the same capacity. Do not sum the purchase and receipt.
Capacity changes invalidate affected confirmation and surface review; never
silently over-allocate or duplicate stock.
"Stale" means the confirmed source/quantity has changed, expired or lost valid
provenance. Opening another view does not itself invalidate a confirmation or
force repetitive stock-entry dialogs. Numeric unknowns always require review.

009 will address cross-device simultaneous allocation conflicts. Until then
local capacity checks are guaranteed; reconciliation after downloaded conflicts
requests review and does not claim global serializable reservations.

## Purchase, undo and receipt lifecycle

Checking an open row buys its visible whole quantity. Freeze its source labels,
dates, portions and allocated amounts in purchaseProvenanceJson so later source
reconciliation cannot rewrite purchase history. This archival JSON does not
replace live contributions/allocations. Freeze that row as a
purchase fact, allocate it once to its contributing demand, and place it under
Kupljeno. Remaining/new demand is represented by outstanding rows; bought rows
are not rewritten during automatic reconciliation. Explicit user undo is
allowed; it is not an automatic change of an immutable purchase fact.

Purchase-to-pantry uses a unique sourceShoppingItemId and an atomic receipt +
outbox write. Repeating it returns the existing receipt. Supply remains one
identity and already allocated amounts are excluded from available stock.

Undo before transfer releases purchase allocations and restores outstanding
demand. If a pantry receipt exists, undo requires explicit stock review first;
do not silently erase a corrected/used pantry receipt. Manual pantry correction
is explicit, followed by affected-demand reconciliation. Cooking flags alone
never decrement pantry quantities.

## Migration, sync and deletion

- Add new SQL files only; extend existing tables plus the three child tables.
  New tables have household RLS, explicit authenticated-only grants, checks,
  household-matching FKs, indexes, timestamps and deletion/tombstone triggers.
- Bump then-current drift schemaVersion and regenerate database.g.dart. Use
  nullable/default-compatible additions for existing rows; backfill entry
  snapshots from existing recipe content where available, retaining ids.
- Do not split legacy bought/manual lists into weeks or invent contributions.
  Keep legacy lists accessible as "Ranija lista" until explicitly associated.
- Register parent-first sync: recipes/plans/entries/lists/items, pantry receipts
  after source purchases, sources after their lists/entries, contributions after items + sources,
  allocations last. Recipe-preparation sources do not require plan parents.
  Existing SyncEntity.parent is single-parent; preserve a topological registry
  order and validate all extra FK parents before upload/deletion.
- Extend fake backend, downloader/uploader, retry, legacy movement, user-cache
  wipe and account deletion. Delete/release child allocations before demand and
  parent rows; never delete a bought/manual record because its plan changed.
- Personal taste/ratings keep own-user policies. No private profile snapshot
  is copied into shared plan rows. All data writes include an outbox entry.
