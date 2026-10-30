import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_format.dart';

Recipe recipe(String title, {List<Ingredient> ingredients = const []}) =>
    Recipe(
      id: title,
      title: title,
      servings: 2,
      ingredients: ingredients,
      source: RecipeSource.manual,
      createdAt: DateTime(2026),
    );

void main() {
  group('količina', () {
    test('decimalni zarez i bez suvišnih nula', () {
      expect(formatQuantity(0.5), '0,5');
      expect(formatQuantity(2), '2');
      expect(formatQuantity(2.0), '2');
      expect(formatQuantity(1.25), '1,25');
      expect(formatQuantity(1 / 3), '0,33');
    });

    test('red sastojka', () {
      expect(
        ingredientLine(
          const Ingredient(name: 'mleveno meso', quantity: 0.5, unit: 'kg'),
        ),
        '0,5 kg mleveno meso',
      );
      expect(
        ingredientLine(const Ingredient(name: 'jaja', quantity: 3)),
        '3 jaja',
      );
      expect(
        ingredientLine(const Ingredient(name: 'biber', note: 'po ukusu')),
        'biber (po ukusu)',
      );
    });
  });

  test('sastojci se grupišu redom kojim se ide kroz prodavnicu', () {
    final groups = groupByCategory(const [
      Ingredient(name: 'biber', category: 'začini i sosovi'),
      Ingredient(name: 'luk', category: 'voće i povrće'),
      Ingredient(name: 'so', category: 'začini i sosovi'),
      Ingredient(name: 'nešto', category: 'nepoznato'),
    ]);
    expect(groups.map((g) => g.$1), [
      'voće i povrće',
      'začini i sosovi',
      'ostalo',
    ]);
    expect(groups[1].$2.map((i) => i.name), ['biber', 'so']);
  });

  group('pretraga', () {
    final all = [recipe('Sarma'), recipe('Pasulj'), recipe('Đuveč')];

    test('ne razlikuje velika slova i kvačice', () {
      expect(filterRecipes(all, 'sar').map((r) => r.title), ['Sarma']);
      expect(filterRecipes(all, 'ŠAR').map((r) => r.title), ['Sarma']);
      expect(filterRecipes(all, 'djuvec').map((r) => r.title), ['Đuveč']);
      expect(filterRecipes(all, 'đuveč').map((r) => r.title), ['Đuveč']);
    });

    test('prazan upit vraća sve', () {
      expect(filterRecipes(all, '  '), all);
    });
  });

  test('datum i vreme', () {
    expect(formatDateTime(DateTime(2026, 3, 7, 9, 5)), '07.03.2026. 09:05');
  });

  test('broj porcija sa pravim padežom', () {
    expect(servingsLabel(1), '1 porcija');
    expect(servingsLabel(2), '2 porcije');
    expect(servingsLabel(4), '4 porcije');
    expect(servingsLabel(5), '5 porcija');
    expect(servingsLabel(12), '12 porcija');
    expect(servingsLabel(21), '21 porcija');
    expect(servingsLabel(22), '22 porcije');
  });
}
