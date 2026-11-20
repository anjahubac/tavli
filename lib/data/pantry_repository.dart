import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/cooked_event.dart';
import '../domain/ids.dart';
import '../domain/meal_plan.dart' show MealType;
import '../domain/plan_calendar.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Ostava domaćinstva; svaka izmena ima outbox u istoj transakciji.
class PantryRepository {
  PantryRepository(
    this._db, {
    required this._scope,
    required this._writer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;
  final DateTime Function() _clock;

  static const _pantryItem = 'pantry_item';

  /// Prima kupljene stavke u ostavu kao potvrđenu zalihu. Prijem je ista
  /// zaliha kao kupovina (ne nova), pa se ne računa dvaput; ponovljen prijem
  /// ne pravi drugi zapis. Vraća broj novih prijema.
  Future<int> receivePurchases(Iterable<String> itemIds) =>
      _db.transaction(() async {
        var received = 0;
        final now = _clock().toUtc();
        for (final itemId in itemIds.toSet()) {
          final item =
              await (_db.select(_db.shoppingItems)..where(
                    (t) =>
                        t.id.equals(itemId) &
                        t.householdId.equals(_scope.householdId),
                  ))
                  .getSingleOrNull();
          if (item == null || !item.isBought) continue;
          final existing =
              await (_db.select(_db.pantryItems)
                    ..where((t) => t.sourceShoppingItemId.equals(itemId)))
                  .getSingleOrNull();
          if (existing != null) continue;
          final id = newId();
          await _db
              .into(_db.pantryItems)
              .insert(
                PantryItemsCompanion.insert(
                  id: id,
                  name: item.name,
                  quantity: Value(item.quantity),
                  unit: Value(item.unit),
                  category: item.category,
                  addedAt: now,
                  confirmedAt: Value(now),
                  sourceShoppingItemId: Value(itemId),
                  householdId: Value(_scope.householdId),
                ),
              );
          await _writer.upsert(_pantryItem, id);
          received++;
        }
        return received;
      });

  /// Kupljene stavke koje su već primljene u ostavu, uživo.
  Stream<Set<String>> watchReceivedItemIds() =>
      (_db.select(_db.pantryItems)..where(
            (t) =>
                t.householdId.equals(_scope.householdId) &
                t.sourceShoppingItemId.isNotNull(),
          ))
          .watch()
          .map((rows) => {for (final r in rows) r.sourceShoppingItemId!});

  /// Ručno brojanje: upisana količina je novo stanje, pa se kuvanje pre ovog
  /// trenutka više ne oduzima (ni kad se kasnije poništi). null = nepoznata.
  Future<void> setQuantity(String itemId, double? quantity) =>
      _db.transaction(() async {
        if (quantity != null && (!quantity.isFinite || quantity < 0)) {
          throw ArgumentError.value(quantity, 'quantity');
        }
        final changed =
            await (_db.update(_db.pantryItems)..where(
                  (t) =>
                      t.id.equals(itemId) &
                      t.householdId.equals(_scope.householdId),
                ))
                .write(
                  PantryItemsCompanion(
                    quantity: Value(quantity),
                    quantitySetAt: Value(_clock().toUtc()),
                  ),
                );
        if (changed > 0) await _writer.upsert(_pantryItem, itemId);
      });

  /// Raspoloživa količina svake stavke ostave (u njenoj jedinici), uživo:
  /// upisana količina minus važeće kuvanje posle poslednjeg brojanja, nikad
  /// ispod nule; null kad količina nije poznata.
  Stream<Map<String, double?>> watchAvailable() {
    final hid = _scope.householdId;
    final items = (_db.select(
      _db.pantryItems,
    )..where((t) => t.householdId.equals(hid))).watch();
    return items.asyncMap((rows) async {
      final events = await (_db.select(
        _db.cookedEvents,
      )..where((t) => t.householdId.equals(hid))).get();
      final byEntry = <String, List<CookedEvent>>{};
      for (final e in events) {
        byEntry
            .putIfAbsent(e.planEntryId, () => [])
            .add(
              CookedEvent(
                id: e.id,
                planEntryId: e.planEntryId,
                mealDate: CivilDate.fromWire(e.mealDate),
                mealType: MealType.lunch,
                actorUserId: e.actorUserId,
                servings: e.servings,
                cookedAt: e.cookedAt,
                undoneAt: e.undoneAt,
              ),
            );
      }
      final counted = {
        for (final list in byEntry.values) ?activeEvent(list)?.id,
      };
      final cookedAt = {for (final e in events) e.id: e.cookedAt};
      final consumptions = <String, List<Consumption>>{};
      for (final c in await (_db.select(
        _db.pantryConsumptions,
      )..where((t) => t.householdId.equals(hid))).get()) {
        consumptions.putIfAbsent(c.pantryItemId, () => []).add((
          eventId: c.eventId,
          pantryItemId: c.pantryItemId,
          micros: c.micros,
        ));
      }
      return {
        for (final r in rows)
          r.id: availableQuantity(
            quantity: r.quantity,
            unit: r.unit,
            quantitySetAt: r.quantitySetAt,
            consumptions: consumptions[r.id] ?? const [],
            counted: counted,
            cookedAt: cookedAt,
          ),
      };
    });
  }
}
