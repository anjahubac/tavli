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
import 'package:tavli/sync/recipe_link_rollout.dart';
import 'package:tavli/sync/synced_writer.dart';

const _scope = AccountScope(userId: 'user-1', householdId: 'home-1');
final _now = DateTime.utc(2026, 11, 23);

void main() {
  late AppDatabase db;
  late ShoppingRepository repository;

  ShoppingRepository build(RecipeLinkRollout rollout) => ShoppingRepository(
    db,
    scope: _scope,
    writer: SyncedWriter(db, accountId: _scope.userId),
    recipeLinkRollout: rollout,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = build(
      const RecipeLinkRollout(
        allDevicesAtCompatibleBuild: true,
        oldOutboxesDrained: true,
      ),
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
        contributions.where((c) => c.ingredientKey == ingredientKey('Maslac')),
        hasLength(1),
      );
    },
  );

  test('pantry stock under the catalog name covers linked demand', () async {
    await catalogStatus(CatalogStatus.available);
    await food('shared');
    await db
        .into(db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            id: 'pantry-butter',
            name: 'maslac',
            quantity: const Value(100),
            unit: const Value('g'),
            category: 'mlečni proizvodi i jaja',
            addedAt: _now,
            confirmedAt: Value(_now),
            householdId: Value(_scope.householdId),
          ),
        );

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
      originKey: 'pantry-covered',
    );

    final item = (await db.select(db.shoppingItems).get()).single;
    expect(item.name, 'Maslac');
    expect(item.quantity, 150);
  });

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
        (c) => c.ingredientKey != ingredientKey('Maslac'),
      ),
      isTrue,
    );
  });

  RecipeSnapshot butterRecipe() => RecipeSnapshot(
    title: 'Test',
    baseServings: 2,
    ingredients: [
      linked('maslac domaći', 100, 'shared'),
      linked('putar', 150, 'shared'),
    ],
  );

  Future<void> setStatus(CatalogStatus status) =>
      (db.update(db.accounts)..where((t) => t.userId.equals(_scope.userId)))
          .write(AccountsCompanion(catalogStatus: Value(status.name)));

  test('a catalog status change keeps linked demand under one key', () async {
    await catalogStatus(CatalogStatus.available);
    await food('shared');
    await repository.addRecipePreparation(
      snapshot: butterRecipe(),
      servings: 2,
      originKey: 'stable-key',
    );
    final before = await db.select(db.shoppingContributions).get();
    final itemsBefore = await db.select(db.shoppingItems).get();
    expect(itemsBefore.single.name, 'Maslac');

    await setStatus(CatalogStatus.failed);
    await repository.reconcileSupply();
    await setStatus(CatalogStatus.notOnServer);
    await repository.reconcileSupply();

    final after = await db.select(db.shoppingContributions).get();
    expect(
      {for (final c in after) c.id: c.ingredientKey},
      {for (final c in before) c.id: c.ingredientKey},
    );
    final itemsAfter = await db.select(db.shoppingItems).get();
    expect(
      [for (final i in itemsAfter) i.id],
      [for (final i in itemsBefore) i.id],
    );
    expect(itemsAfter.single.name, 'Maslac');
    expect(itemsAfter.single.quantity, 250);
  });

  test('links are ignored while the rollout guard is closed', () async {
    repository = build(const RecipeLinkRollout());
    await catalogStatus(CatalogStatus.available);
    await food('shared');
    await repository.addRecipePreparation(
      snapshot: butterRecipe(),
      servings: 2,
      originKey: 'closed-rollout',
    );

    final items = await db.select(db.shoppingItems).get();
    expect(
      items.map((i) => i.name),
      unorderedEquals(['maslac domaći', 'putar']),
    );
  });
}
