import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/domain/recipe_allergens.dart';

void main() {
  test('real coverage requires each ingredient to have a reviewed mapping', () {
    final catalog = <String, Set<AllergenGroup>>{
      'milk': {AllergenGroup.milk},
      'salt': {},
    };
    final checked = RecipeAllergens.resolve(['milk', 'salt'], catalog);
    expect(checked.groups, {AllergenGroup.milk});
    expect(checked.isComplete, isTrue);
    expect(checked.conflictsWith({AllergenGroup.milk}), isTrue);
    expect(checked.conflictsWith({AllergenGroup.eggs}), isFalse);

    final sevenOfEight = RecipeAllergens.resolve([
      ...List.filled(6, 'salt'),
      'milk',
      null,
    ], catalog);
    expect(sevenOfEight.isComplete, isFalse);
    expect(sevenOfEight.hasUnresolvedIngredient, isTrue);
    expect(sevenOfEight.groups, {AllergenGroup.milk});

    final unreviewed = RecipeAllergens.resolve(['linked'], catalog);
    expect(unreviewed.hasUnresolvedIngredient, isFalse);
    expect(unreviewed.hasUnreviewedMapping, isTrue);
    expect(unreviewed.isComplete, isFalse);
    expect(RecipeAllergens.resolve([], catalog).isComplete, isFalse);
  });
}
