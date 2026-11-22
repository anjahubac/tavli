/// Personal likes and dislikes keyed by the catalog's stable food IDs.
class FoodPreferences {
  factory FoodPreferences({
    Set<String> liked = const {},
    Set<String> disliked = const {},
  }) {
    if (![...liked, ...disliked].every(_foodId.hasMatch)) {
      throw ArgumentError('Identifikator namirnice nije ispravan.');
    }
    return FoodPreferences._(
      Set.unmodifiable(liked.difference(disliked)),
      Set.unmodifiable(disliked),
    );
  }

  const FoodPreferences._(this.liked, this.disliked);

  final Set<String> liked;
  final Set<String> disliked;

  static final _foodId = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  factory FoodPreferences.fromJson(Map<String, Object?> json) =>
      FoodPreferences(
        liked: _read(json['likedFoodIds']),
        disliked: _read(json['dislikedFoodIds']),
      );

  Map<String, Object?> toJson() => {
    'likedFoodIds': liked.toList()..sort(),
    'dislikedFoodIds': disliked.toList()..sort(),
  };

  static Set<String> _read(Object? raw) {
    if (raw == null) return const {};
    if (raw is! List<Object?>) {
      throw const FormatException('Izbor namirnica mora biti lista.');
    }
    return raw.whereType<String>().where(_foodId.hasMatch).toSet();
  }
}
