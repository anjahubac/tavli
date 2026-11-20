# Contract: cooked meal operation (v1)

**Status**: Accepted by Dev 4 (Anja) on 2026-11-19, all proposed answers D1–D6;
implemented on branch `021-cooked-meal-operation` (producer slice). Dev 1 and
Dev 3 confirm D1, D2 and D4 in the implementing PR review before merge.
**Spec**: [021 requirements](../spec.md) FR-007, Q1; tasks T014–T015.
Shared boundary [C5](../../011-team-development/contracts/shared-boundaries.md).
**Producer**: Dev 4 (Anja) — the operation, its record and pantry consumption.
**Consumers / reviewers**: Dev 1 (Uroš) — shopping demand; Dev 3 (Matija) —
optional private intake diary ([023](../../023-optional-nutrition/spec.md)).
Pantry rules come from [022](../../022-simple-pantry/spec.md).
**Date**: 2026-11-19 | **Trello**: [Događaj „obrok skuvan“](https://trello.com/c/AZBjlbwl)

## Purpose

One place in the code is called whenever a planned meal is marked cooked or the
mark is undone. Home (“Skuvano”), the Plan meal sheet, and later cooking mode all
call it. Shopping, pantry and the intake diary react to the same recorded
operation instead of each listening to a button. It is a repository/service
call, not a global event bus (C5).

This contract answers four questions: which meal, who cooked it, cooked or
undone; why a repeated or undone mark never reduces the pantry twice; what
happens when someone edits a pantry quantity after cooking; and what each
consumer may rely on.

## Existing behavior (dev 8968b9a)

- `meal_plan_entries.is_cooked` is a plain boolean
  (`lib/data/database.dart`, `MealPlanEntries`), toggled by
  `MealPlanRepository.setCooked(entryId, cooked:)`
  (`lib/data/meal_plan_repository.dart`). There is no record of who cooked,
  when, or with which servings.
- The only caller is the Plan meal sheet
  (`lib/features/planning/meal_entry_detail.dart`, “Označi kao skuvano” /
  “Nije skuvano”).
- `ShoppingRepository.reconcilePlan` closes the meal's shopping source
  (`closed_at`) while `is_cooked` is true and reopens it when false. A closed
  source no longer receives supply allocations, so its pantry reservation is
  released. Bought items and pantry stock are not changed.
- Cooking does not reduce the pantry today. `pantry_items.quantity` is a
  nullable real; `confirmed_at` marks stock the person confirmed.
- Sync uploads whole rows and the server keeps the last write (`upsert` on
  `id`, `lib/sync/uploader.dart`). Two devices that each write a decremented
  `pantry_items.quantity` would lose one decrement. This is why this contract
  never writes consumption into the quantity column.

## Interface

### Service

```dart
/// lib/data/cooking_repository.dart; provider `cookingRepositoryProvider`
/// in lib/features/planning/planning_providers.dart
class CookingRepository {
  /// Marks the entry cooked. Returns the active event; if the entry is
  /// already cooked, returns the existing event and changes nothing. A meal
  /// cooked before this change (no event) returns null and changes nothing.
  Future<CookedEvent?> markCooked(String entryId);

  /// Undoes the active event of the entry. No active event: no-op, returns null.
  Future<CookedEvent?> undoCooked(String entryId);

  /// Live state for Home/Plan (null = not cooked).
  Stream<CookedEvent?> watchActive(String entryId);
}
```

`MealPlanRepository.setCooked` stays as the low-level flag write used by this
service; widgets no longer call it. Types live in `lib/domain/cooked_event.dart`.

### Record: `CookedEvent`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID, client-generated | Operation identity. Replays and duplicate uploads are recognised by it. |
| `householdId` | UUID | From `AccountScope`; RLS scope, as for plan rows. |
| `planEntryId` | UUID | Which meal. A cooked meal cannot be removed (existing `ProtectedMealException`). |
| `mealDate` | CivilDate (`YYYY-MM-DD`) | Copied from the entry; a local date, not a UTC timestamp. |
| `mealType` | `MealType` name (`breakfast`, `morningSnack`, `lunch`, `afternoonSnack`, `dinner`) | Copied from the entry. |
| `actorUserId` | UUID | Who pressed “Skuvano” (`AccountScope.userId`). Only this person's intake can be written automatically. |
| `servings` | int 1–20 | Entry servings at cook time (`servings ?? snapshot.baseServings`). |
| `cookedAt` | UTC timestamp | Device clock at mark time. |
| `undoneAt` | UTC timestamp, nullable | Set once on undo; never cleared. |
| `undoReason` | `user`, nullable | Set together with `undoneAt`. |

A meal is cooked when it has exactly one event with `undoneAt == null`.
Undo never deletes the event; cooking again after undo creates a **new** event
with a new `id`. So every event goes through at most one transition
(active → undone) and every reversal is linked to the operation it reverses.

The recipe is not copied into the event: a cooked meal's snapshot and servings
cannot change (existing `ProtectedMealException`, `regenerableSlots`), so
consumers read the entry's approved snapshot, never the live library recipe.

`meal_plan_entries.is_cooked` stays as a projection of “has an active event”,
written in the same transaction, so existing shopping code, `regenerableSlots`
and the meal cards keep working unchanged.

### Pantry consumption: ledger, not a decrement

Cooking writes one row per consumed pantry item; it never rewrites
`pantry_items.quantity`.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID | |
| `eventId` | UUID | The `CookedEvent`. Unique `(eventId, pantryItemId)`: a replay cannot add a second row. |
| `pantryItemId` | UUID | |
| `baseUnit` | string | Base unit of the item's unit group (`g`, `ml`, `kom`, …). |
| `micros` | int > 0 | Amount in `baseUnit`, integer micros (C4). Taken from the supply allocation, which already matched the unit group (`normalizeUnit`); exact conversion between groups waits for [017](../../017-kitchen-unit-conversion/spec.md). |

Available quantity of a pantry item:

```
available = max(0, quantity − Σ micros of consumptions whose event is active
                               and whose event.cookedAt > item.quantitySetAt)
```

- **Repeated “Skuvano”** returns the existing active event; no new rows.
- **Replay after offline restart** upserts the same event and the same
  consumption ids; the unique key makes the second write a no-op.
- **Undo** sets `undoneAt`; its consumptions stop counting immediately. The rows
  stay for history. A second undo finds no active event and does nothing.
- **Cook → undo → cook** creates a second event with its own rows; only the
  active one counts. Stock is reduced once at any moment.
- **Zero floor**: the sum may exceed the stored quantity (two meals use the same
  oil); the displayed value is floored at 0 and is never negative. Undoing one
  of them restores exactly its share, because nothing was clamped when written.
- **Unknown quantity** items (`quantity == null`) and items whose unit does not
  convert are not consumed. They stay present until the person removes them
  (022 FR-104). Only confirmed stock (`confirmed_at != null`) is consumed.
- **Matching**: an ingredient consumes from the pantry item(s) that covered its
  demand when it was planned, i.e. the existing supply allocations for that
  meal's source. An allocation from a purchase counts when that purchase was
  received into the pantry (`source_shopping_item_id`). Without an allocation,
  no consumption. This keeps the choice of
  “which bag of flour” in one place (Dev 1's allocation) instead of a new
  name-matching rule (decision D2).

### Manual pantry edit after cooking

A manual quantity change is a new count of what is physically there, so it wins
over earlier cooking.

- Saving a quantity from the Ostava edit sheet writes `quantity` and a new
  column `quantitySetAt = now`. Consumptions from events cooked before that
  moment no longer count (formula above); later ones do.
- Undoing a meal cooked **before** the manual edit changes the meal, shopping
  and intake, but does not add stock back, because the person's count already
  reflects reality. The undo snackbar on Home stays “Poništi” with no extra
  text; the pantry simply does not change (decision D3).
- Undoing a meal cooked **after** the edit restores its consumption as usual.
- Deleting a pantry item deletes its consumption rows (server cascade, like
  supply allocations). 022's remove-with-undo should therefore delay the delete
  until the undo window closes instead of recreating the item.
- `cookedAt` and `quantitySetAt` come from device clocks. A wrong clock can put
  a cook on the wrong side of an edit; the effect is bounded to that one meal
  and is corrected by the next manual edit. Accepted limitation.

### Transaction boundary

`markCooked` / `undoCooked` run in one drift transaction:

1. load the entry (household scope; another household gets
   `MealNotFoundException`). A meal without a recipe snapshot can still be
   cooked; it simply has no pantry consumption;
2. insert or update the `CookedEvent`, set `is_cooked`;
3. insert pantry consumption rows (mark) or nothing (undo — they stop counting);
4. `ShoppingRepository.reconcilePlan(planId)` — Dev 1, existing;
5. run registered `CookedEffect`s (below);
6. outbox entries for every row written.

```dart
/// Implemented by consumers that need their own rows; called inside the
/// transaction. Must be idempotent by event.id.
abstract interface class CookedEffect {
  Future<void> onCooked(CookedEvent event);
  Future<void> onUndone(CookedEvent event);
}
```

Dev 3's intake diary registers one `CookedEffect`. When tracking is off for the
actor, it does nothing. When on, it writes one owner-only intake row keyed by
`event.id` for `actorUserId` only; `onUndone` marks it reversed. Other household
members confirm “Jela sam” themselves; cooking never writes their diaries
(023 FR-104, US2). The effect runs only on the device that performed the
operation; events downloaded from other devices are not re-applied, because the
rows they produced sync themselves.

Any effect failure rolls back the whole transaction; the button shows an error
and nothing is half-cooked.

## State transitions and examples (synthetic data)

Pantry: brašno 1 000 g (set 10:00), mleko — unknown quantity. Meal: palačinke,
lunch 2026-11-20, 4 servings, needs 250 g brašno + 500 ml mleko.

| Step | Event | Brašno available | Mleko | Shopping source |
| --- | --- | --- | --- | --- |
| Mark cooked 12:00 | E1 active | 750 g | present | closed |
| Tap “Skuvano” again | E1 (no-op) | 750 g | present | closed |
| Offline replay of E1 | E1 (no-op) | 750 g | present | closed |
| “Poništi” | E1 undone | 1 000 g | present | open |
| “Poništi” again | no-op | 1 000 g | present | open |
| Mark cooked 13:00 | E2 active | 750 g | present | closed |
| Manual edit 14:00: 600 g | E2 active | 600 g | present | closed |
| “Poništi” 15:00 | E2 undone | 600 g (count wins) | present | open |

## Concurrency and sync

- New synced tables: `cooked_events`, `pantry_consumptions`; new column
  `pantry_items.quantity_set_at`. Household RLS, grants to `authenticated` only,
  two-account pgTAP tests, drift `schemaVersion` bump with migration test.
  Exact versions are allocated after the preceding schema PRs merge.
- Two devices that cooked the same meal offline both upload an active event.
  Nothing is rewritten on download: every client treats the earliest
  `(cookedAt, id)` active event as the meal's event (`activeEvent`), and only
  that event's consumption counts, so stock is reduced once. Undo closes every
  active event of the meal.
- Undo on one device and a second “Skuvano” on another: the undone event stays
  undone, the new event is active; the meal ends cooked once.
- An `undoneAt` update and a stale upload of the same active event: a set
  `undoneAt` is never cleared, and meal, actor, servings and `cookedAt` never
  change (server trigger `private.keep_cooked_event`).
- Server rows: migration `supabase/migrations/20261119120000_cooked_events.sql`,
  household RLS, grants to `authenticated` only; the actor must be a member of
  the same household (any member may upload the row, because undo by another
  member re-sends it). Tests: `supabase/tests/09_cooked_events_test.sql`.
  Local drift schema version 7 (version 6 is the recipe labels change).

## Compatibility

- Entries already `is_cooked = true` before migration get no event and no pantry
  consumption (legacy cooked). Undo on such a meal creates nothing to reverse
  and only clears `is_cooked`.
- Old builds toggle `is_cooked` without an event. Only team dev builds exist,
  so all developers update together after merge; this change adds no
  compatibility layer for old builds (decision D5).
- Ratings (`ratings.cooked_at`) stay separate and are not written by this
  operation.

## Known follow-ups (not in this slice)

- Home “Skuvano” and cooking mode do not exist on `dev` yet; when built they
  call `CookingRepository`. The Plan meal sheet already does.
- Ostava has no quantity edit sheet yet; `PantryRepository.setQuantity` and
  `watchAvailable` are the API it will use.
- Dev 1: shopping supply capacity still uses the stored `pantry_items.quantity`,
  and a cooked meal keeps its allocation. After a manual count the cooked meal
  still holds part of that count, so later meals may show more to buy than
  needed. `setQuantity` also does not reconcile shopping. Dev 1 decides whether
  capacity should use `watchAvailable` and release cooked allocations.
- Dev 3: no intake `CookedEffect` is registered yet.

## Tests (fixtures for producer and consumers)

- Mark twice, replay, undo twice, cook-undo-cook: stock and shopping source match
  the table above.
- Two meals consume the same item past zero: display 0, undo one restores its
  share exactly.
- Manual edit between cook and undo: count wins.
- Unknown quantity and non-convertible units: unchanged.
- Duplicate offline events from two devices converge to one active event.
- Intake effect: actor gets one row; another member gets none; replay does not
  duplicate; tracking off writes nothing.
- Two-account RLS: a member of another household cannot read or write events
  or consumptions.
- Home “Skuvano” and the Plan sheet call the same service (Trello done criterion).

## Decisions

| # | Question | Decision (2026-11-19) | Owner / confirms |
| --- | --- | --- | --- |
| D1 | Shopping keeps reacting to `is_cooked` through `reconcilePlan`, no new hook. | Yes. | Dev 4 accepted; Dev 1 confirms |
| D2 | Pantry consumption follows existing supply allocations of the meal instead of new name matching. | Yes; no allocation, no consumption. | Dev 4 accepted; Dev 1 confirms |
| D3 | After a manual edit, undo of an earlier cook does not restore stock. Show a hint? | Count wins; no hint in v1. | Dev 4 accepted |
| D4 | Intake via `CookedEffect` in the same transaction, owner-only row keyed by event id. | Yes. | Dev 4 accepted; Dev 3 confirms |
| D5 | No compatibility layer for builds older than this change. | Yes, dev builds only. | Dev 4 accepted |
| D6 | Which device's clock orders a cook against a manual edit. | Device clock, accepted limitation. | Dev 4 accepted |

This contract adds no new UI copy. Existing copy stays: “Skuvano”, “Poništi”,
“Označi kao skuvano”, “Nije skuvano”.
