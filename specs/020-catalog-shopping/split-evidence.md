# Shopping repository split: baseline and proposed boundaries

**Status:** Independent baseline research; the split has not been approved or
implemented. Source D1-004 / FR-001 in [spec 020](spec.md); proposed review
by Dev 4. Q1 still requires agreement on boundaries before dependent work.

## Baseline

At team `dev` commit `928d655b32035d752332763840cc5c4b0e281697`,
`lib/data/shopping_repository.dart` has 1,383 lines. The original task targets
smaller files of approximately 400 lines without changing behavior. That is a
review goal, not evidence that an arbitrary line-based split preserves the
transaction and synchronization contracts.

Existing responsibilities include:

| Area | Current examples | Boundary risk |
| --- | --- | --- |
| Public read results | `PlanTotal`, `PlanShoppingItem`, `RecipePreparation` | Existing imports and public types must remain compatible. |
| Legacy list and recipe delta | `_ensureList`, `plan`, `addMissing`, `markHave` | Repeated additions, shared items and bought rows must remain stable. |
| Plan and standalone sources | `weekList`, `reconcilePlan`, `addRecipePreparation`, `removeSource` | Weekly identity, snapshots, source lifecycle and idempotency. |
| Read/watch and totals | `watchPlanItems`, `watchRecipeItems`, `planTotals`, `totalsOf` | Do not create another persisted monthly list or alter aggregation. |
| Manual/bought operations | `addManual`, `deleteManual`, `setBought`, `_buy`, `_unbuy` | Preserve purchase provenance and received-purchase behavior. |
| Reconciliation and deletion | `_demand`, `_reconcile`, `_deleteSource`, `_deleteContribution` | Shared supply capacity, write ordering, transactions and outbox rows. |

`shopping_demand.dart`, `supply_allocation.dart` and `shopping_sync.dart`
already contain domain logic. A split should use those existing boundaries and
avoid introducing a second calculator or synchronization queue.

## Independent baseline check

On 2026-11-15, with Flutter 3.50.0, the following passed on the team baseline:

```sh
flutter test --no-pub test/data/shopping_repository_test.dart \
  test/domain/shopping_demand_test.dart test/domain/supply_allocation_test.dart
```

Result: 47 tests passed. They cover repeated addition, different recipes sharing
supply, bought/manual rows, weekly/monthly behavior and the 300/100/200/400 g
purchase/receipt example. These tests use fakes and local databases; they do not
prove a future split, live server RLS or old/new-version compatibility. A
separate [offline replay PR](https://github.com/anjahubac/tavli/pull/33) has
additional fake-backed evidence and was not merged into this baseline.

## Candidate extraction sequence for team review

1. Inventory consumers and confirm ownership with Dev 4. Consider moving
   immutable read-result types and pure total calculation behind an unchanged
   public API. Preserve exports/imports and compare outputs for empty,
   unknown, bought and multi-week cases.
2. Separate read/watch assembly from writes only after deciding their concrete
   interface. Keep stream invalidation and household scoping observable to the
   same consumers.
3. Separate source lifecycle and purchase operations in small reviewed slices.
   Keep every row mutation and its outbox entry in the same existing
   transaction; preserve parent/child order, retries and deletion behavior.
4. Only with an agreed interface, isolate reconciliation orchestration from
   pure demand/allocation logic. Preserve historical snapshots, physical supply
   identity, ordering, unknown quantities and idempotency. Do not reinterpret
   past quantities or combine this refactor with catalog/unit migrations.
5. Check each resulting file against the approximately 400-line task goal and
   explain any exception to reviewers. Run the current baseline and additional
   tests for every affected public behavior; verify schema and user data are
   unchanged.

These are candidate steps, not accepted design decisions or a promise that
the first extraction alone meets the file-size target. Confirm exact file
names, boundaries and review order before code changes. No D1-004 task is
marked complete by this document.

## Proposed split

A first concrete split keeps `ShoppingRepository`, its constructor and every
public method and type unchanged, so no consumer changes. The library is split
with `part` files, and each part is a private mixin on one shared private
base, so moved methods stay ordinary instance members and need no new imports:

| File | Lines | Contents |
| --- | --- | --- |
| `lib/data/shopping_repository.dart` | 306 | Class, fields, shared base, legacy list and recipe delta, list and week lookup, `totalsOf` |
| `lib/data/shopping_sources.dart` | 384 | Plan and standalone sources: `reconcilePlan`, `addRecipePreparation`, preparations, `removeSource`, source and contribution deletion, demand, legacy unit migration of closed sources |
| `lib/data/shopping_items.dart` | 339 | Read/watch of items, manual items, `itemSources`, buy and unbuy, `planTotals` |
| `lib/data/shopping_reconcile.dart` | 418 | `_reconcile` only |

Method bodies are moved without edits. The only code changes are the outbox
entity names, now library-level constants instead of static class members,
and `ShoppingRepository.totalsOf` qualified at its one call inside a part.
Transactions, write order, outbox entries and stream queries are untouched.
`_reconcile` is a single method of about 410 lines; meeting the 400-line goal
there means splitting its logic, which this refactor deliberately does not do
(step 4 above needs an agreed interface first).

Step 4 and a decision on whether `part` plus mixins is the preferred style
remain for Dev 4's review.
