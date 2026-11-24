import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_sync.dart';
import 'package:tavli/sync/catalog_status.dart';

import '../../helpers/test_app.dart';

const _foodNames = [
  'krompir',
  'šargarepa',
  'tikvica',
  'paprika',
  'grašak',
  'karfiol',
  'brokoli',
  'blitva',
];

Future<void> _seedFoods(AppDatabase db, int covered) async {
  final t = DateTime.utc(2026, 11, 21);
  await db
      .update(db.accounts)
      .write(
        AccountsCompanion(catalogStatus: Value(CatalogStatus.available.name)),
      );
  for (final (index, name) in _foodNames.indexed) {
    final hasNutrition = index < covered;
    await db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            id: 'food-$index',
            slug: 'food-$index',
            name: name,
            category: 'ostalo',
            baseUnit: 'gram',
            kcalPer100g: Value(hasNutrition ? 100 : null),
            proteinGramsPer100g: Value(hasNutrition ? 10 : null),
            fatGramsPer100g: Value(hasNutrition ? 2 : null),
            carbsGramsPer100g: Value(hasNutrition ? 15 : null),
            nutritionSource: Value(hasNutrition ? 'synthetic' : null),
            nutritionSourceVersion: Value(hasNutrition ? 'test' : null),
            nutritionSourceRef: Value(hasNutrition ? 'sample-$index' : null),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }
}

Future<void> _openRecipe(
  WidgetTester tester, {
  required int covered,
  bool linked = true,
}) async {
  await pumpTavli(
    tester,
    location: '/recipes/nutrition-test',
    setup: (db) => _seedFoods(db, covered),
    recipes: [_recipe(linked: linked)],
  );
  expect(find.text('Testni recept'), findsWidgets);
  expect(find.textContaining('blitva'), findsOneWidget);
}

Recipe _recipe({required bool linked}) => Recipe(
  id: 'nutrition-test',
  title: 'Testni recept',
  servings: 2,
  ingredients: [
    for (final (index, name) in _foodNames.indexed)
      Ingredient(
        name: name,
        quantity: 100,
        unit: 'g',
        link: linked
            ? IngredientLink(
                foodId: 'food-$index',
                matchedKey: ingredientKey(name),
                linkSource: LinkSource.confirmed,
              )
            : null,
      ),
  ],
  source: RecipeSource.manual,
  createdAt: DateTime.utc(2026, 11, 21),
);

void main() {
  testTavli('detalj recepta prikazuje procenu za 7 od 8 sastojaka', (
    tester,
  ) async {
    await _openRecipe(tester, covered: 7);

    // Seven 100 g contributions divided by two servings.
    expect(
      find.text(
        'Po porciji ~350 kcal · proteini 35 g · masti 7 g'
        ' · ugljeni hidrati 52,5 g',
      ),
      findsOneWidget,
    );
    expect(find.text('Računato za 7 od 8 sastojaka.'), findsOneWidget);
  });

  testTavli('detalj recepta skriva nutritivni blok pri nultoj pokrivenosti', (
    tester,
  ) async {
    await _openRecipe(tester, covered: 0);

    expect(find.textContaining('Po porciji'), findsNothing);
    expect(find.textContaining('Računato'), findsNothing);
  });

  testTavli('procena staje na širokom ekranu sa dvostrukim tekstom', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(
      tester,
      size: wide,
      location: '/recipes/nutrition-test',
      setup: (db) => _seedFoods(db, 7),
      recipes: [_recipe(linked: true)],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Računato za 7 od 8 sastojaka.'), findsOneWidget);
  });

  testTavli('recept bez povezanih sastojaka ne prikazuje broj', (tester) async {
    await _openRecipe(tester, covered: 8, linked: false);

    expect(find.textContaining('Po porciji'), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
  });
}
