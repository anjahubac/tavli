import 'allergen_group.dart';

/// Catalog-derived information for displaying a recipe and its warnings.
/// The only personal input accepted here is the active user's own selection.
class RecipeAllergens {
  const RecipeAllergens._({
    required this.groups,
    required this.hasUnresolvedIngredient,
    required this.hasUnreviewedMapping,
  });

  /// Use null for an unmatched or invalid food ID. A linked ID absent from
  /// [reviewedGroups] has unknown metadata. An empty set is reviewed absence.
  factory RecipeAllergens.resolve(
    Iterable<String?> ingredientFoodIds,
    Map<String, Set<AllergenGroup>> reviewedGroups,
  ) {
    final groups = <AllergenGroup>{};
    var hasUnresolvedIngredient = ingredientFoodIds.isEmpty;
    var hasUnreviewedMapping = false;
    for (final foodId in ingredientFoodIds) {
      if (foodId == null || foodId.trim().isEmpty) {
        hasUnresolvedIngredient = true;
        continue;
      }
      final mapped = reviewedGroups[foodId];
      if (mapped == null) {
        hasUnreviewedMapping = true;
      } else {
        groups.addAll(mapped);
      }
    }
    return RecipeAllergens._(
      groups: Set.unmodifiable(groups),
      hasUnresolvedIngredient: hasUnresolvedIngredient,
      hasUnreviewedMapping: hasUnreviewedMapping,
    );
  }

  final Set<AllergenGroup> groups;
  final bool hasUnresolvedIngredient;
  final bool hasUnreviewedMapping;

  bool get isComplete => !hasUnresolvedIngredient && !hasUnreviewedMapping;

  bool conflictsWith(Set<AllergenGroup> ownSelection) =>
      groups.any(ownSelection.contains);
}
