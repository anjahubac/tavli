import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/domain/shopping_sync.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli/sync/synced_writer.dart';

const _scope = AccountScope(userId: 'user-1', householdId: 'home-1');
final _now = DateTime.utc(2026, 11, 23);

void main() {
  late AppDatabase db;
  late ShoppingRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ShoppingRepository(
      db,
      scope: _scope,
      writer: SyncedWriter(db, accountId: _scope.userId),
    );
  });

  tearDown(() => db.close());

  Future<void> catalogStatus(CatalogStatus status) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          userId: _scope.userId,
          email: 'test@example.com',
          householdId: _scope.householdId,
          householdName: 'Test',
          role: 'owner',
          catalogStatus: Value(status.name),
          createdAt: _now,
        ),
      );

  Future<void> food(String id, {String? householdId, DateTime? withdrawnAt}) =>
      db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              id: id,
              householdId: Value(householdId),
              slug: id,
              name: 'Maslac',
              category: 'mlečni proizvodi i jaja',
              baseUnit: 'gram',
              withdrawnAt: Value(withdrawnAt),
              createdAt: _now,
              updatedAt: _now,
            ),
          );

  Ingredient linked(
    String name,
    double quantity,
    String foodId, {
    String? key,
  }) => Ingredient(
    name: name,
    quantity: quantity,
    unit: 'g',
    link: IngredientLink(
      foodId: foodId,
      matchedKey: key ?? ingredientKey(name),
      linkSource: LinkSource.confirmed,
    ),
  );

  test(
    'groups visible active IDs; stale, withdrawn and foreign links fall back',
    () async {
      await catalogStatus(CatalogStatus.available);
      await food('shared');
      await food('foreign', householdId: 'home-2');
      await food('withdrawn', withdrawnAt: _now);

      await repository.addRecipePreparation(
        snapshot: RecipeSnapshot(
          title: 'Test',
          baseServings: 2,
          ingredients: [
            linked('maslac domaći', 100, 'shared'),
            linked('putar', 150, 'shared'),
            linked('strani sastojak', 30, 'foreign'),
            linked('stari naziv', 40, 'shared', key: 'old-name'),
            linked('povučeni sastojak', 50, 'withdrawn'),
          ],
        ),
        servings: 2,
        originKey: 'test-recipe',
      );

      final items = await db.select(db.shoppingItems).get();
      expect(items, hasLength(4));
      final canonical = items.singleWhere((item) => item.name == 'Maslac');
      expect(canonical.quantity, 250);
      expect(canonical.unit, 'g');
      expect(
        items.map((item) => item.name),
        containsAll(['strani sastojak', 'stari naziv', 'povučeni sastojak']),
      );
      final contributions = await db.select(db.shoppingContributions).get();
      expect(
        contributions.where((c) => c.ingredientKey == 'food:shared'),
        hasLength(1),
      );
    },
  );

  test('catalog failure never merges by an unverified link', () async {
    await catalogStatus(CatalogStatus.failed);
    await food('shared');

    await repository.addRecipePreparation(
      snapshot: RecipeSnapshot(
        title: 'Test',
        baseServings: 2,
        ingredients: [
          linked('maslac domaći', 100, 'shared'),
          linked('putar', 150, 'shared'),
        ],
      ),
      servings: 2,
      originKey: 'failed-catalog',
    );

    expect(await db.select(db.shoppingItems).get(), hasLength(2));
    expect(
      (await db.select(db.shoppingContributions).get()).every(
        (c) => !c.ingredientKey.startsWith('food:'),
      ),
      isTrue,
    );
  });
}
