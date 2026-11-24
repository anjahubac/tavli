import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';
import '../../data/food_catalog_reader.dart';
import '../../domain/food_matcher.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_nutrition.dart';
import '../../providers.dart';
import '../../sync/catalog_status.dart';

/// Ključ proračuna: recept, porcije i sastojci (sa vezama) kao tekst, da se
/// procena osveži kad se recept izmeni.
typedef RecipeNutritionKey = ({String id, int servings, String ingredients});

RecipeNutritionKey recipeNutritionKey(Recipe recipe) => (
  id: recipe.id,
  servings: recipe.servings,
  ingredients: jsonEncode([for (final i in recipe.ingredients) i.toJson()]),
);

/// Procena po porciji iz lokalnog keša kataloga (radi i bez mreže); null kad
/// nijedan sastojak nema poznate vrednosti.
final recipeNutritionProvider = FutureProvider.autoDispose
    .family<NutritionPerPortion?, RecipeNutritionKey>((ref, key) async {
      final scope = ref.watch(accountScopeProvider);
      if (scope == null) return null;
      final db = ref.watch(databaseProvider);
      final account = await db.select(db.accounts).getSingleOrNull();
      final status =
          CatalogStatus.values.asNameMap()[account?.catalogStatus] ??
          CatalogStatus.notOnServer;
      final ingredients = [
        for (final item in jsonDecode(key.ingredients) as List<Object?>)
          Ingredient.fromJson(item! as Map<String, dynamic>),
      ];
      return FoodCatalogReader(db).nutritionForRecipe(
        FoodLookupScope(householdId: scope.householdId),
        ingredients: ingredients,
        servings: key.servings,
        status: status,
      );
    });

/// „Po porciji ~350 kcal · …“ i pokrivenost. Ništa se ne prikazuje kad nijedan
/// sastojak nije pokriven, umesto pogrešnog broja.
class RecipeNutritionLine extends ConsumerWidget {
  const RecipeNutritionLine({required this.recipe, super.key});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref
        .watch(recipeNutritionProvider(recipeNutritionKey(recipe)))
        .value;
    if (value == null || value.coveredIngredients == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TavliSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nutritionSummary(value), style: theme.textTheme.bodyLarge),
          const SizedBox(height: TavliSpacing.small),
          Text(
            'Računato za ${value.coveredIngredients} od '
            '${value.totalIngredients} sastojaka.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// „Po porciji ~350 kcal · proteini 35 g · masti 7 g · ugljeni hidrati 52,5 g“.
String nutritionSummary(NutritionPerPortion value) =>
    'Po porciji ~${value.kcal.round()} kcal'
    ' · proteini ${_grams(value.proteinGrams)} g'
    ' · masti ${_grams(value.fatGrams)} g'
    ' · ugljeni hidrati ${_grams(value.carbsGrams)} g';

String _grams(double value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}
