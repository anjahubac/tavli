import 'food_conversion.dart';
import 'food_matcher.dart';
import 'recipe.dart';
import 'shopping_demand.dart';
import 'shopping_sync.dart';

/// A source record that contributed to a calculated recipe portion.
final class NutritionSourceReference {
  const NutritionSourceReference({
    required this.source,
    required this.version,
    required this.reference,
  });

  final String source;
  final String version;
  final String reference;

  @override
  bool operator ==(Object other) =>
      other is NutritionSourceReference &&
      other.source == source &&
      other.version == version &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(source, version, reference);
}

/// Calculated calories and macros for one recipe portion.
final class NutritionPerPortion {
  const NutritionPerPortion({
    required this.kcal,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.coveredIngredients,
    required this.totalIngredients,
    required this.sources,
  });

  final double kcal;
  final double proteinGrams;
  final double fatGrams;
  final double carbsGrams;

  /// Ingredients with a current exact link, complete attributed nutrition and
  /// a known mass conversion.
  final int coveredIngredients;
  final int totalIngredients;
  final Set<NutritionSourceReference> sources;
}

/// Calculates a recipe's per-portion nutrients from linked catalog values.
/// Only exact mass conversions are applied here. Volume/count units without an
/// accepted gram conversion, unknown nutrients, stale links and unresolved
/// ingredients remain uncovered rather than being treated as zero.
NutritionPerPortion? recipeNutritionPerPortion({
  required Iterable<Ingredient> ingredients,
  required int servings,
  required Map<String, FoodIdentity> foodsById,
}) {
  if (servings <= 0) return null;
  final items = ingredients.toList(growable: false);
  if (items.isEmpty) return null;

  var kcal = 0.0;
  var protein = 0.0;
  var fat = 0.0;
  var carbs = 0.0;
  var covered = 0;
  final sources = <NutritionSourceReference>{};

  for (final item in items) {
    final link = item.link;
    if (link == null || link.matchedKey != ingredientKey(item.name)) continue;
    final food = foodsById[link.foodId];
    if (food == null || food.id != link.foodId) continue;
    final nutrition = food.nutrition;
    if (nutrition == null ||
        nutrition.kcalPer100g == null ||
        nutrition.proteinGramsPer100g == null ||
        nutrition.fatGramsPer100g == null ||
        nutrition.carbsGramsPer100g == null) {
      continue;
    }
    final converted = convertQuantity(
      quantity: item.quantity,
      unit: item.unit,
      target: FoodBaseUnit.gram,
    );
    if (converted is! Converted || converted.base != FoodBaseUnit.gram) {
      continue;
    }
    final grams = fromMicros(converted.micros);
    final portionScale = grams / 100 / servings;
    final itemKcal = nutrition.kcalPer100g! * portionScale;
    final itemProtein = nutrition.proteinGramsPer100g! * portionScale;
    final itemFat = nutrition.fatGramsPer100g! * portionScale;
    final itemCarbs = nutrition.carbsGramsPer100g! * portionScale;
    if (![
      itemKcal,
      itemProtein,
      itemFat,
      itemCarbs,
    ].every((value) => value.isFinite)) {
      continue;
    }
    kcal += itemKcal;
    protein += itemProtein;
    fat += itemFat;
    carbs += itemCarbs;
    covered++;
    sources.add(
      NutritionSourceReference(
        source: nutrition.source,
        version: nutrition.sourceVersion,
        reference: nutrition.sourceRef,
      ),
    );
  }

  if (covered == 0 ||
      ![kcal, protein, fat, carbs].every((value) => value.isFinite)) {
    return null;
  }
  return NutritionPerPortion(
    kcal: kcal,
    proteinGrams: protein,
    fatGrams: fat,
    carbsGrams: carbs,
    coveredIngredients: covered,
    totalIngredients: items.length,
    sources: Set.unmodifiable(sources),
  );
}
