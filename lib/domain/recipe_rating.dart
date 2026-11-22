/// The signed-in person's current rating for a saved recipe.
class RecipeRating {
  const RecipeRating({
    required this.recipeId,
    required this.stars,
    required this.cookedAt,
    this.personalNote,
  });

  final String recipeId;
  final int stars;
  final DateTime cookedAt;
  final String? personalNote;
}

/// Household-visible aggregate. It contains no member-level data.
class RecipeRatingSummary {
  const RecipeRatingSummary({
    required this.averageStars,
    required this.ratingCount,
  });

  final double averageStars;
  final int ratingCount;
}
