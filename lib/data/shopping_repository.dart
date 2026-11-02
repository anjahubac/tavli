import 'dart:convert';

import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/ids.dart';
import '../domain/recipe.dart';
import '../domain/shopping_sync.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Kupovina domaćinstva; svaka izmena ima outbox u istoj transakciji.
class ShoppingRepository {
  ShoppingRepository(
    this._db, {
    required this._scope,
    required this._writer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;
  final DateTime Function() _clock;

  Future<String> _ensureList() => _db.transaction(() async {
    final existing =
        await (_db.select(_db.shoppingLists)
              ..where(
                (t) =>
                    t.householdId.equals(_scope.householdId) &
                    t.mealPlanId.isNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await _db
        .into(_db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            name: 'Kupovina',
            createdAt: _clock().toUtc(),
            householdId: Value(_scope.householdId),
          ),
        );
    await _writer.upsert('shopping_list', id);
    return id;
  });

  static List<String> _recipes(ShoppingItemRow row) => [
    for (final id in jsonDecode(row.fromRecipeIdsJson) as List<dynamic>)
      id as String,
  ];

  Future<List<ShoppingItemRow>> _items() async {
    final id = await _ensureList();
    return (_db.select(_db.shoppingItems)..where(
          (t) => t.listId.equals(id) & t.householdId.equals(_scope.householdId),
        ))
        .get();
  }

  Future<ShoppingSyncPlan> plan(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) async {
    final rows = [
      for (final row in await _items())
        if (_recipes(row).contains(recipeId)) row,
    ];
    return planRecipeShopping(
      missing: missing,
      have: have,
      inList: {for (final row in rows) ingredientKey(row.name)},
      bought: {
        for (final row in rows)
          if (row.isBought) ingredientKey(row.name),
      },
    );
  }

  /// Ponovni klik dodaje samo razliku; drugi recept deli postojeću stavku.
  Future<List<Ingredient>> addMissing(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) => _db.transaction(() async {
    final p = await plan(recipeId, missing: missing, have: have);
    final listId = await _ensureList();
    final open = {
      for (final row in await _items())
        if (!row.isBought) ingredientKey(row.name): row,
    };
    for (final ingredient in p.toAdd) {
      final existing = open[ingredientKey(ingredient.name)];
      if (existing != null) {
        await (_db.update(
          _db.shoppingItems,
        )..where((t) => t.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            fromRecipeIdsJson: Value(
              jsonEncode([..._recipes(existing), recipeId]),
            ),
          ),
        );
        await _writer.upsert('shopping_item', existing.id);
      } else {
        final id = newId();
        await _db
            .into(_db.shoppingItems)
            .insert(
              ShoppingItemsCompanion.insert(
                id: id,
                listId: listId,
                name: ingredient.name,
                quantity: Value(ingredient.quantity),
                unit: Value(ingredient.unit),
                category: ingredient.category,
                fromRecipeIdsJson: Value(jsonEncode([recipeId])),
                householdId: Value(_scope.householdId),
              ),
            );
        await _writer.upsert('shopping_item', id);
      }
    }
    return p.toAdd;
  });

  /// "Imam" uklanja samo doprinos ovog recepta; kupljeno ostaje.
  Future<bool> markHave(String recipeId, Ingredient ingredient) =>
      _db.transaction(() async {
        var removed = false;
        for (final row in await _items()) {
          final recipes = _recipes(row);
          if (row.isBought ||
              ingredientKey(row.name) != ingredientKey(ingredient.name) ||
              !recipes.contains(recipeId)) {
            continue;
          }
          removed = true;
          final rest = [...recipes]..remove(recipeId);
          if (rest.isEmpty && !row.isManual) {
            await (_db.delete(
              _db.shoppingItems,
            )..where((t) => t.id.equals(row.id))).go();
            await _writer.delete('shopping_item', row.id);
          } else {
            await (_db.update(
              _db.shoppingItems,
            )..where((t) => t.id.equals(row.id))).write(
              ShoppingItemsCompanion(
                fromRecipeIdsJson: Value(jsonEncode(rest)),
              ),
            );
            await _writer.upsert('shopping_item', row.id);
          }
        }
        return removed;
      });

  Future<int> openCount() async =>
      (await _items()).where((row) => !row.isBought).length;
  Future<List<String>> openNames() async => [
    for (final row in await _items())
      if (!row.isBought) row.name,
  ];

  Future<void> markBought(String name) => _db.transaction(() async {
    for (final row in await _items()) {
      if (ingredientKey(row.name) == ingredientKey(name) && !row.isBought) {
        await (_db.update(_db.shoppingItems)..where((t) => t.id.equals(row.id)))
            .write(const ShoppingItemsCompanion(isBought: Value(true)));
        await _writer.upsert('shopping_item', row.id);
      }
    }
  });
}
