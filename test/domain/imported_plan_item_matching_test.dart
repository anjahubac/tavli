import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/food_matcher.dart';

// Spec 030 (Trello #32): povezivanje već izdvojenih stavki uvezenog plana sa
// katalogom. Model uvoza (#52) još ne postoji, pa je stavka ovde lokalni
// sintetički zapis; matcher je postojeći AliasFoodMatcher.
class ExtractedItem {
  const ExtractedItem({
    required this.originalText,
    required this.recognitionName,
    required this.quantity,
    required this.unit,
  });

  final String originalText;
  final String recognitionName;
  final num quantity;
  final String unit;
}

/// Stavka posle povezivanja: `foodId == null` znači da traži oznaku „Proveri“.
class LinkedItem {
  const LinkedItem(this.item, this.foodId);

  final ExtractedItem item;
  final String? foodId;

  bool get needsReview => foodId == null;
}

Future<LinkedItem> link(FoodMatcher matcher, ExtractedItem item) async {
  final r = await matcher.findByName(
    originalText: item.recognitionName,
    scope: const FoodLookupScope(householdId: 'A'),
  );
  return LinkedItem(item, r is Matched ? r.food.id : null);
}

void main() {
  const crniLuk = FoodIdentity(
    id: 'food-crni-luk',
    slug: 'crni-luk',
    name: 'crni luk',
    category: 'Povrće',
    baseUnit: FoodBaseUnit.gram,
  );
  final matcher = AliasFoodMatcher(
    const [],
    foods: const [CatalogFood(crniLuk)],
  );

  const onion = ExtractedItem(
    originalText: '150 g crnog luka',
    recognitionName: 'crni luk',
    quantity: 150,
    unit: 'g',
  );
  const mix = ExtractedItem(
    originalText: '80 g domaće mešavine',
    recognitionName: 'domaća mešavina',
    quantity: 80,
    unit: 'g',
  );

  test(
    'normalizovan naziv „crni luk“ se povezuje sa ID-jem iz kataloga',
    () async {
      final linked = await link(matcher, onion);
      expect(linked.foodId, 'food-crni-luk');
      expect(linked.needsReview, isFalse);
    },
  );

  test(
    'original sa količinom, bez normalizacije naziva, ostaje Unresolved',
    () async {
      final r = await matcher.findByName(
        originalText: onion.originalText,
        scope: const FoodLookupScope(householdId: 'A'),
      );
      expect(r, isA<Unresolved>());
    },
  );

  test('domaća mešavina bez pouzdanog poklapanja ostaje bez ID-ja', () async {
    final linked = await link(matcher, mix);
    expect(linked.foodId, isNull);
    expect(linked.needsReview, isTrue);
  });
}
