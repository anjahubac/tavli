# Future implementation validation guide

**Status:** run after the tasks are implemented. This documentation revision does
not create the listed screens/test files or claim checks have already passed.

## Prerequisites

- Start implementation from latest main after 005 is merged, on the 010 branch
  brought up to date according to repository git rules. Keep auth and wake lock.
- Provide local-only Supabase configuration separately. Tests use fakes and
  the local stack; never read real keys, use hosted production or reset user data.
- Complete [UX evaluation](contracts/ux.md) using synthetic data before polishing
  a final UI. Implementation tasks are not complete merely because a prototype exists.

## Automated checks (after implementation)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
scripts/check.sh
flutter build macos --debug
supabase start
supabase db reset
supabase test db
```

Database reset above applies only to the disposable local Supabase stack. The
native user cache must migrate in place. Generated code accompanies its source.

## Core journey with fake/synthetic data

1. Sign in and complete name; Plan opens. Verify old recipe/profile/shopping
   return links and avatar access from every tab.
2. Choose a calendar month crossing six weeks, all three meal types and
   editable portions. Do not enter pantry/preferences; a first plan can still
   be proposed. Check the one-screen essentials setup.
3. Use fake AI batches. Interrupt one, retain the preview, resume missing work,
   replace a suggestion, lock another and explicitly save. Discard a separate
   draft and verify no saved data changes.
4. Change the same library recipe later; approved plan quantities/content stay.
   Try regeneration with locked, cooked and past slots; all remain unchanged.
5. Open the selected week's Nabavka within two navigation taps. Check grouped
   ingredient amounts, per-occurrence servings and source-meal details.
6. Repeat a recipe across dates/weeks and send/reconcile twice. Quantities count
   both occurrences exactly once; month view does not create new purchase rows.
7. Verify the accounting fixture: demand 300 g, confirmed home stock 100 g,
   purchase 200 g, transfer to pantry twice, revised demand 400 g → 100 g to buy.
8. Confirm compatible g/kg and ml/l aggregation; incompatible or unknown amounts
   remain reviewable. Never silently interpret "po ukusu" as a numeric quantity.
9. Add an unrelated manual item, mark another bought, replace/remove a meal and
   verify both manual/bought records remain. Undo purchase before and after a
   pantry receipt; the latter requires explicit stock review.
10. Search/edit pantry, flag stock expiring in seven days, confirm quantities
    and use it for a plan. One stock quantity cannot cover several weeks twice.
11. Open today's meal with approved steps and cooking within two navigation taps. Follow saved
    steps offline, check wake lock release/choice, mark cooked and optionally
    rate/favorite. Pantry is not silently decremented; cooked demand stays closed after later
    stock corrections. Missing steps enter an explicit completion/review flow.
12. Disconnect; read and manually edit saved plans/shopping/pantry. Reconnect
    through fake backend/local stack; queued changes upload without duplication.
13. Use two unrelated accounts. Neither sees the other's household data or
    private taste/ratings. Sign-out retains each cache and pending outbox.

## Layout and usability matrix

Run the same journey at 320×900, 400×800 and 1200×800; text 1×/2×; light/dark;
normal/reduced motion; keyboard and one-handed phone shopping. Check primary
action hierarchy, selected-state labels, focus, semantics and ≥48 targets.
Test both fresh empty and realistically populated data, not just ideal cards.

Evaluate with five first-time participants and record results in the UX report
using [UX-006](contracts/ux.md). Target ≥4 completing without coaching; fix and
retest failed tasks. A failed UX gate prevents marking the feature complete.

## Migration and performance

- Open a real temporary file with the previous schema, existing IDs, plans,
  bought/manual items and queued changes; migrate, restart and round-trip sync.
  Retain old lists without inventing weekly purchases or zero stock.
- Confirm new child entities are handled by registry ordering, deletion,
  tombstones, account wipe and legacy import; local pgTAP checks RLS/grants/FKs.
- Benchmark 93 entries / 1,000 contributions on a named reference device and
  record reconciliation latency. Target <1 s; do not benchmark against production.

## Standalone recipe path (no plan required)

With zero plans, open a saved/searched recipe and an unsaved AI/image preview.
Inspect ingredients and portions: no data is saved. Confirm home stock and
explicitly add missing shopping: a source snapshot is saved without a hidden
library recipe or fake plan. Add twice, untick one "imam" and add again: only
the delta changes. Choose an explicit repeat for a later preparation and verify
it is distinct. If already planned, select its existing context or explicitly
choose a separate preparation. Test the shared supply/receipt capacity across
both modes, and first-time-user comprehension of "Po planu"/"Po receptu".
