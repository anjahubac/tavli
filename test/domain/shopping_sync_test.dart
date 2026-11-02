import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_sync.dart';

const krompir = Ingredient(name: 'Krompir');
const meso = Ingredient(name: 'Mleveno meso');
const luk = Ingredient(name: 'Crni luk');

void main() {
  test('ključ sastojka ne zavisi od velikih slova i razmaka', () {
    expect(ingredientKey('  Crni Luk '), ingredientKey('crni luk'));
  });

  test('dodaje samo nedostajuće kojih još nema u kupovini', () {
    final plan = planRecipeShopping(
      missing: const [krompir, luk],
      have: const [meso],
      inList: {ingredientKey('krompir')},
    );
    expect(plan.toAdd.map((i) => i.name), ['Crni luk']);
    expect(plan.toRemove, isEmpty);
  });

  test('"imam" za stavku koju je recept već dodao (nekupljenu) je uklanja', () {
    final plan = planRecipeShopping(
      missing: const [krompir],
      have: const [meso, luk],
      inList: {ingredientKey('krompir'), ingredientKey('crni luk')},
    );
    expect(plan.toAdd, isEmpty);
    expect(plan.toRemove, [ingredientKey('crni luk')]);
  });

  test('kupljena stavka se ne uklanja', () {
    final plan = planRecipeShopping(
      missing: const [],
      have: const [luk],
      inList: {ingredientKey('crni luk')},
      bought: {ingredientKey('crni luk')},
    );
    expect(plan.toRemove, isEmpty);
  });

  test('isti sastojak dvaput u receptu se dodaje jednom', () {
    final plan = planRecipeShopping(
      missing: const [
        luk,
        Ingredient(name: 'crni luk'),
      ],
      have: const [],
      inList: const {},
    );
    expect(plan.toAdd, hasLength(1));
  });
}
