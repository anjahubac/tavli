import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/food_matcher.dart';
import 'package:tavli/domain/food_nutrition.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_nutrition.dart';
import 'package:tavli/domain/shopping_sync.dart';

FoodIdentity food({
  required String id,
  required String name,
  FoodNutrition? nutrition,
}) => FoodIdentity(
  id: id,
  slug: id,
  name: name,
  category: 'ostalo',
  baseUnit: FoodBaseUnit.gram,
  nutrition: nutrition,
);

FoodNutrition values(double kcal) => FoodNutrition(
  kcalPer100g: kcal,
  proteinGramsPer100g: 2,
  fatGramsPer100g: 1,
  carbsGramsPer100g: 5,
  source: 'USDA FoodData Central',
  sourceVersion: 'SR Legacy 2018-04',
  sourceRef: 'FDC 1',
);

Ingredient linked(String id, String name, double? quantity, String? unit) =>
    Ingredient(
      name: name,
      quantity: quantity,
      unit: unit,
      link: IngredientLink(
        foodId: id,
        matchedKey: ingredientKey(name),
        linkSource: LinkSource.confirmed,
      ),
    );

void main() {
  test('calculates attributed values per recipe portion from grams', () {
    final potato = food(id: 'potato', name: 'krompir', nutrition: values(77));
    final result = recipeNutritionPerPortion(
      ingredients: [linked('potato', 'krompir', 200, 'g')],
      servings: 2,
      foodsById: {'potato': potato},
    )!;

    expect(result.kcal, closeTo(77, 1e-9));
    expect(result.proteinGrams, closeTo(2, 1e-9));
    expect(result.fatGrams, closeTo(1, 1e-9));
    expect(result.carbsGrams, closeTo(5, 1e-9));
    expect((result.coveredIngredients, result.totalIngredients), (1, 1));
    expect(result.sources.single.reference, 'FDC 1');
  });

  test('converts known mass units without display rounding', () {
    final potato = food(id: 'potato', name: 'krompir', nutrition: values(77));
    final result = recipeNutritionPerPortion(
      ingredients: [linked('potato', 'krompir', 1, 'kg')],
      servings: 2,
      foodsById: {'potato': potato},
    )!;
    expect(result.kcal, closeTo(385, 1e-9));
  });

  test('unknown and unconvertible ingredients remain uncovered', () {
    final potato = food(id: 'potato', name: 'krompir', nutrition: values(77));
    final result = recipeNutritionPerPortion(
      ingredients: [
        linked('potato', 'krompir', 100, 'g'),
        linked('missing', 'nepoznato', 30, 'g'),
        linked('potato', 'krompir', 1, 'kom'),
        linked('potato', 'krompir', 10, 'g').copyWith(name: 'drugačije'),
      ],
      servings: 1,
      foodsById: {'potato': potato},
    )!;
    expect(result.kcal, closeTo(77, 1e-9));
    expect((result.coveredIngredients, result.totalIngredients), (1, 4));
  });

  test(
    'reports partial coverage without counting unknown nutrition as zero',
    () {
      final ingredients = [
        for (var i = 0; i < 7; i++) linked('food-$i', 'namirnica $i', 100, 'g'),
        linked('unknown', 'nepoznato', 100, 'g'),
      ];
      final foods = {
        for (var i = 0; i < 7; i++)
          'food-$i': food(
            id: 'food-$i',
            name: 'namirnica $i',
            nutrition: values(10),
          ),
      };
      final result = recipeNutritionPerPortion(
        ingredients: ingredients,
        servings: 2,
        foodsById: foods,
      )!;

      expect((result.coveredIngredients, result.totalIngredients), (7, 8));
      expect(result.kcal, closeTo(35, 1e-9));
    },
  );

  test('returns no result when nothing is covered or servings are invalid', () {
    final potato = food(id: 'potato', name: 'krompir', nutrition: values(77));
    expect(
      recipeNutritionPerPortion(
        ingredients: [linked('potato', 'krompir', 2, 'kom')],
        servings: 1,
        foodsById: {'potato': potato},
      ),
      isNull,
    );
    expect(
      recipeNutritionPerPortion(
        ingredients: [linked('potato', 'krompir', 100, 'g')],
        servings: 0,
        foodsById: {'potato': potato},
      ),
      isNull,
    );
  });
}
