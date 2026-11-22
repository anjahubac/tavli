import 'recipe_labels.dart';

/// Personal likes and dislikes for the existing recipe dish-kind labels.
class DishKindPreferences {
  factory DishKindPreferences({
    Set<DishKind> liked = const {},
    Set<DishKind> disliked = const {},
  }) => DishKindPreferences._(
    liked: Set.unmodifiable(liked.difference(disliked)),
    disliked: Set.unmodifiable(disliked),
  );

  const DishKindPreferences._({required this.liked, required this.disliked});

  final Set<DishKind> liked;
  final Set<DishKind> disliked;

  factory DishKindPreferences.fromJson(Map<String, Object?> json) {
    final liked = _readKinds(json, 'likedDishKinds');
    final disliked = _readKinds(json, 'dislikedDishKinds');
    return DishKindPreferences(liked: liked, disliked: disliked);
  }

  Map<String, Object?> toJson() => {
    'likedDishKinds': [
      for (final kind in DishKind.values)
        if (liked.difference(disliked).contains(kind)) kind.wire,
    ],
    'dislikedDishKinds': [
      for (final kind in DishKind.values)
        if (disliked.contains(kind)) kind.wire,
    ],
  };

  static Set<DishKind> _readKinds(Map<String, Object?> json, String key) {
    final raw = json[key];
    if (raw == null) return const {};
    if (raw is! List<Object?>) {
      throw FormatException('Polje $key mora biti lista.');
    }
    return {for (final value in raw) ?DishKind.tryParse(value)};
  }

  @override
  bool operator ==(Object other) =>
      other is DishKindPreferences &&
      liked.length == other.liked.length &&
      liked.containsAll(other.liked) &&
      disliked.length == other.disliked.length &&
      disliked.containsAll(other.disliked);

  @override
  int get hashCode => Object.hashAll([
    ...liked.map((kind) => kind.wire).toSet(),
    ...disliked.map((kind) => kind.wire).toSet(),
  ]);
}
