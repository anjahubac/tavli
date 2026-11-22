/// Pretraga recepata na uređaju: naziv i filteri po oznakama i vremenu
/// (specs/019-meal-selection-rules/contracts/recipe-search-contract.md).
///
/// Ista funkcija služi listi recepata, a kasnije i planu i predlogu iz
/// ostave. Radi nad receptima iz lokalne baze, pa radi i bez mreže.
library;

import 'recipe.dart';
import 'recipe_format.dart';
import 'recipe_labels.dart';

/// Ponuđene granice vremena pripreme, u minutima.
const prepTimeLimits = [15, 30, 60];

/// Upit za pretragu. Prazan filter (`null`) ne sužava ništa; uključen
/// filter propušta samo recepte za koje je ta osobina poznata i odgovara.
class RecipeFilter {
  const RecipeFilter({
    this.query = '',
    this.meal,
    this.weight,
    this.dishKind,
    this.maxPrepMinutes,
  });

  static const none = RecipeFilter();

  /// Deo naziva; mala/velika slova i kvačice se ne razlikuju.
  final String query;
  final MealSuitability? meal;
  final DishWeight? weight;
  final DishKind? dishKind;

  /// Najviše toliko minuta pripreme.
  final int? maxPrepMinutes;

  /// Broj uključenih filtera, bez naziva.
  int get activeFilters =>
      [meal, weight, dishKind, maxPrepMinutes].where((f) => f != null).length;

  bool get hasFilters => activeFilters > 0;

  bool get isEmpty => query.trim().isEmpty && !hasFilters;

  RecipeFilter copyWith({
    String? query,
    MealSuitability? Function()? meal,
    DishWeight? Function()? weight,
    DishKind? Function()? dishKind,
    int? Function()? maxPrepMinutes,
  }) => RecipeFilter(
    query: query ?? this.query,
    meal: meal == null ? this.meal : meal(),
    weight: weight == null ? this.weight : weight(),
    dishKind: dishKind == null ? this.dishKind : dishKind(),
    maxPrepMinutes: maxPrepMinutes == null
        ? this.maxPrepMinutes
        : maxPrepMinutes(),
  );

  /// Isti naziv, bez filtera.
  RecipeFilter cleared() => RecipeFilter(query: query);

  @override
  bool operator ==(Object other) =>
      other is RecipeFilter &&
      other.query == query &&
      other.meal == meal &&
      other.weight == weight &&
      other.dishKind == dishKind &&
      other.maxPrepMinutes == maxPrepMinutes;

  @override
  int get hashCode =>
      Object.hash(query, meal, weight, dishKind, maxPrepMinutes);
}

/// Recepti koji ispunjavaju sve uslove iz [filter], istim redom.
List<Recipe> searchRecipes(Iterable<Recipe> recipes, RecipeFilter filter) {
  if (filter.isEmpty) return List.of(recipes);
  final q = normalizeForSearch(filter.query);
  return [
    for (final r in recipes)
      if (_matches(r, filter, q)) r,
  ];
}

bool _matches(Recipe r, RecipeFilter f, String q) {
  if (q.isNotEmpty && !normalizeForSearch(r.title).contains(q)) return false;
  if (f.meal case final meal? when !r.labels.mealSet.contains(meal)) {
    return false;
  }
  if (f.weight case final weight? when r.labels.weightValue != weight) {
    return false;
  }
  if (f.dishKind case final kind? when r.labels.dishKindValue != kind) {
    return false;
  }
  if (f.maxPrepMinutes case final max?) {
    final minutes = r.prepMinutes;
    if (minutes == null || minutes > max) return false;
  }
  return true;
}
