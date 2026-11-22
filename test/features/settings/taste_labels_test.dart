import 'package:flutter_test/flutter_test.dart';

import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/features/settings/tastes/taste_labels.dart';

void main() {
  test('oblik reči uz broj', () {
    String allergens(int n) => countLabel(n, 'alergen', 'alergena', 'alergena');
    String favorites(int n) => countLabel(
      n,
      'omiljeni recept',
      'omiljena recepta',
      'omiljenih recepata',
    );
    expect(allergens(1), '1 alergen');
    expect(allergens(21), '21 alergen');
    expect(allergens(11), '11 alergena');
    expect(favorites(3), '3 omiljena recepta');
    expect(favorites(12), '12 omiljenih recepata');
    expect(favorites(5), '5 omiljenih recepata');
  });

  test('pregled na Profilu izostavlja nule', () {
    expect(
      tastesSummary(allergens: 2, likes: 6, favorites: 3),
      '2 alergena · 6 sviđanja · 3 omiljena recepta',
    );
    expect(tastesSummary(allergens: 0, likes: 1, favorites: 0), '1 sviđanje');
    expect(
      tastesSummary(allergens: 0, likes: 0, favorites: 0),
      'Ništa nije izabrano',
    );
  });

  test('svaki alergen iz kataloga ima naziv i ikonicu, bez ponavljanja', () {
    expect(
      allergenChoices.map((a) => a.$1).toSet(),
      AllergenGroup.values.toSet(),
    );
    expect(allergenChoices, hasLength(AllergenGroup.values.length));
  });
}
