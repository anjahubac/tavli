import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/dish_kind_preferences.dart';
import 'package:tavli/domain/recipe_labels.dart';

void main() {
  test('overlap resolves to dislike and values use DishKind wire order', () {
    final preferences = DishKindPreferences(
      liked: {DishKind.sweet, DishKind.pasta, DishKind.cooked},
      disliked: {DishKind.pasta},
    );

    expect(preferences.liked, {DishKind.cooked, DishKind.sweet});
    expect(preferences.disliked, {DishKind.pasta});
    expect(preferences.toJson(), {
      'likedDishKinds': ['cooked', 'sweet'],
      'dislikedDishKinds': ['pasta'],
    });
  });

  test('unknown stored kinds are ignored and absent fields are empty', () {
    expect(
      DishKindPreferences.fromJson({
        'likedDishKinds': ['pasta', 'future_kind', 'pasta'],
      }),
      DishKindPreferences(liked: {DishKind.pasta}),
    );
    expect(
      DishKindPreferences.fromJson({'unrelated': true}),
      DishKindPreferences(),
    );
  });

  test('rejects non-list preference fields', () {
    expect(
      () => DishKindPreferences.fromJson({'likedDishKinds': 'pasta'}),
      throwsFormatException,
    );
  });
}
