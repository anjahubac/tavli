/// Wire codes shared with the meal planner.
enum Cuisine { serbian, italian, japanese, french, mexican }

class CuisinePreferences {
  factory CuisinePreferences({
    Set<Cuisine> liked = const {},
    Set<Cuisine> disliked = const {},
  }) => CuisinePreferences._(
    Set.unmodifiable(liked.difference(disliked)),
    Set.unmodifiable(disliked),
  );

  const CuisinePreferences._(this.liked, this.disliked);

  final Set<Cuisine> liked;
  final Set<Cuisine> disliked;

  factory CuisinePreferences.fromJson(Map<String, Object?> json) =>
      CuisinePreferences(
        liked: _read(json['likedCuisineCodes']),
        disliked: _read(json['dislikedCuisineCodes']),
      );

  Map<String, Object?> toJson() => {
    'likedCuisineCodes': [
      for (final cuisine in Cuisine.values)
        if (liked.contains(cuisine)) cuisine.name,
    ],
    'dislikedCuisineCodes': [
      for (final cuisine in Cuisine.values)
        if (disliked.contains(cuisine)) cuisine.name,
    ],
  };

  static Set<Cuisine> _read(Object? raw) {
    if (raw == null) return const {};
    if (raw is! List<Object?>) {
      throw const FormatException('Izbor kuhinja mora biti lista.');
    }
    return {
      for (final cuisine in Cuisine.values)
        if (raw.contains(cuisine.name)) cuisine,
    };
  }
}
