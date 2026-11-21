import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../data/database.dart';
import 'entities.dart';
import 'synced_writer.dart';

/// Usvaja serverski ID nedeljne liste koju je drugi uređaj već napravio.
/// Poziva se u transakciji preuzimanja jednog zapisa.
Future<bool> adoptShoppingWeek(
  AppDatabase db,
  AccountScope scope,
  ShoppingListEntity entity,
  Map<String, Object?> payload,
) async {
  final canonical = entity.fromRemote(payload);
  final planId = canonical.mealPlanId.value;
  final start = canonical.periodStart.value;
  if (planId == null ||
      start == null ||
      canonical.householdId.value != scope.householdId) {
    return false;
  }

  final lists = db.shoppingLists;
  final local =
      await (db.select(lists)..where(
            (t) =>
                t.householdId.equals(scope.householdId) &
                t.mealPlanId.equals(planId) &
                t.periodStart.equals(start) &
                t.id.isNotValue(canonical.id.value),
          ))
          .getSingleOrNull();
  if (local == null) return false;

  final outbox = db.syncOutbox;
  final listEdits = db.select(outbox)
    ..where(
      (t) =>
          t.accountId.equals(scope.userId) &
          t.entity.equals(entity.name) &
          t.recordId.equals(local.id) &
          t.op.equals(OutboxOp.upsert),
    );
  // Prevezujemo samo listu koja još ima lokalno kreiranje u redu za slanje.
  if ((await listEdits.get()).isEmpty) return false;

  final localList = db.update(lists)..where((t) => t.id.equals(local.id));
  await localList.write(const ShoppingListsCompanion(periodStart: Value(null)));
  await entity.write(db, payload);

  final items = db.selectOnly(db.shoppingItems)
    ..addColumns([db.shoppingItems.id])
    ..where(db.shoppingItems.listId.equals(local.id));
  final sources = db.selectOnly(db.shoppingSources)
    ..addColumns([db.shoppingSources.id])
    ..where(db.shoppingSources.listId.equals(local.id));
  final contributions = db.selectOnly(db.shoppingContributions)
    ..addColumns([db.shoppingContributions.id])
    ..where(db.shoppingContributions.sourceId.isInQuery(sources));
  final allocations = db.selectOnly(db.supplyAllocations)
    ..addColumns([db.supplyAllocations.id])
    ..where(
      db.supplyAllocations.contributionId.isInQuery(contributions) |
          db.supplyAllocations.purchasedShoppingItemId.isInQuery(items),
    );
  final pantry = db.selectOnly(db.pantryItems)
    ..addColumns([db.pantryItems.id])
    ..where(db.pantryItems.sourceShoppingItemId.isInQuery(items));

  // Ponovo šaljemo zavisne upise koje je server odbio zbog stranog ključa.
  await (db.update(outbox)..where(
        (t) =>
            t.accountId.equals(scope.userId) &
            t.op.equals(OutboxOp.upsert) &
            t.state.equals(OutboxState.rejected) &
            t.lastError.equals('23503') &
            ((t.entity.equals('shopping_item') & t.recordId.isInQuery(items)) |
                (t.entity.equals('shopping_source') &
                    t.recordId.isInQuery(sources)) |
                (t.entity.equals('shopping_contribution') &
                    t.recordId.isInQuery(contributions)) |
                (t.entity.equals('supply_allocation') &
                    t.recordId.isInQuery(allocations)) |
                (t.entity.equals('pantry_item') &
                    t.recordId.isInQuery(pantry))),
      ))
      .write(
        const SyncOutboxCompanion(
          state: Value(OutboxState.pending),
          lastError: Value(null),
        ),
      );

  await (db.update(db.shoppingItems)..where((t) => t.listId.equals(local.id)))
      .write(ShoppingItemsCompanion(listId: canonical.id));
  await (db.update(db.shoppingSources)..where((t) => t.listId.equals(local.id)))
      .write(ShoppingSourcesCompanion(listId: canonical.id));
  await (db.delete(lists)..where((t) => t.id.equals(local.id))).go();
  await (db.delete(outbox)..where(
        (t) =>
            t.accountId.equals(scope.userId) &
            t.entity.equals(entity.name) &
            t.recordId.equals(local.id),
      ))
      .go();
  return true;
}
