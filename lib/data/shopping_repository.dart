import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/recipe.dart';
import '../domain/shopping_sync.dart';
import 'database.dart';

/// Lista za kupovinu (za sada jedna, "Kupovina") i usklađivanje sa
/// sastojcima recepta.
class ShoppingRepository {
  ShoppingRepository(this._db);

  final AppDatabase _db;

  static const defaultListId = 'kupovina';

  Future<String> _ensureList() async {
    await _db
        .into(_db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: defaultListId,
            name: 'Kupovina',
            createdAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return defaultListId;
  }

  static List<String> _recipes(ShoppingItemRow row) => [
    for (final id in jsonDecode(row.fromRecipeIdsJson) as List<dynamic>)
      id as String,
  ];

  Future<List<ShoppingItemRow>> _items() async {
    final listId = await _ensureList();
    return (_db.select(
      _db.shoppingItems,
    )..where((i) => i.listId.equals(listId))).get();
  }

  /// Plan za recept: šta bi "Dodaj u kupovinu" dodalo i šta treba ukloniti.
  Future<ShoppingSyncPlan> plan(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) async {
    final fromRecipe = [
      for (final row in await _items())
        if (_recipes(row).contains(recipeId)) row,
    ];
    return planRecipeShopping(
      missing: missing,
      have: have,
      inList: {for (final r in fromRecipe) ingredientKey(r.name)},
      bought: {
        for (final r in fromRecipe)
          if (r.isBought) ingredientKey(r.name),
      },
    );
  }

  /// Dodaje samo razliku i vraća šta je dodato. Ako isti sastojak već
  /// postoji (nekupljen) iz drugog recepta, samo mu se doda ovaj recept.
  Future<List<Ingredient>> addMissing(
    String recipeId, {
    required List<Ingredient> missing,
    required List<Ingredient> have,
  }) => _db.transaction(() async {
    final p = await plan(recipeId, missing: missing, have: have);
    final open = {
      for (final row in await _items())
        if (!row.isBought) ingredientKey(row.name): row,
    };
    for (final i in p.toAdd) {
      final existing = open[ingredientKey(i.name)];
      if (existing != null) {
        await (_db.update(
          _db.shoppingItems,
        )..where((r) => r.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            fromRecipeIdsJson: Value(
              jsonEncode([..._recipes(existing), recipeId]),
            ),
          ),
        );
      } else {
        await _db
            .into(_db.shoppingItems)
            .insert(
              ShoppingItemsCompanion.insert(
                listId: defaultListId,
                name: i.name,
                quantity: Value(i.quantity),
                unit: Value(i.unit),
                category: i.category,
                fromRecipeIdsJson: Value(jsonEncode([recipeId])),
              ),
            );
      }
    }
    return p.toAdd;
  });

  /// Korisnik ima sastojak: ako ga je ovaj recept stavio u kupovinu, a nije
  /// kupljen, recept se skida sa stavke (stavka nestaje kad ostane bez recepta).
  Future<bool> markHave(String recipeId, Ingredient ingredient) =>
      _db.transaction(() async {
        final key = ingredientKey(ingredient.name);
        var removed = false;
        for (final row in await _items()) {
          final recipes = _recipes(row);
          if (row.isBought ||
              ingredientKey(row.name) != key ||
              !recipes.contains(recipeId)) {
            continue;
          }
          removed = true;
          final rest = [...recipes]..remove(recipeId);
          final query = _db.shoppingItems.id.equals(row.id);
          if (rest.isEmpty && !row.isManual) {
            await (_db.delete(_db.shoppingItems)..where((_) => query)).go();
          } else {
            await (_db.update(_db.shoppingItems)..where((_) => query)).write(
              ShoppingItemsCompanion(
                fromRecipeIdsJson: Value(jsonEncode(rest)),
              ),
            );
          }
        }
        return removed;
      });

  /// Broj nekupljenih stavki (bedž na tabu "Kupovina").
  Future<int> openCount() async => [
    for (final row in await _items())
      if (!row.isBought) row,
  ].length;

  Future<List<String>> openNames() async => [
    for (final row in await _items())
      if (!row.isBought) row.name,
  ];

  Future<void> markBought(String name) async {
    final key = ingredientKey(name);
    for (final row in await _items()) {
      if (ingredientKey(row.name) == key) {
        await (_db.update(_db.shoppingItems)..where((r) => r.id.equals(row.id)))
            .write(const ShoppingItemsCompanion(isBought: Value(true)));
      }
    }
  }
}
