import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/pantry_ai.dart';

void main() {
  test('čita stavke, normalizuje jedinicu i kategoriju', () {
    final items = photoItemsFromAiResponse({
      'items': [
        {
          'name': ' mleko ',
          'quantity': 1,
          'unit': 'l',
          'category': 'mlečni proizvodi i jaja',
        },
        {'name': 'so', 'quantity': null, 'unit': 'kg', 'category': 'nepoznato'},
        {'name': 'hleb', 'quantity': -2, 'unit': 'kom'},
      ],
    });
    expect(items.map((i) => i.name), ['mleko', 'so', 'hleb']);
    expect(items[0].quantity, 1);
    expect(items[0].unit, 'l');
    expect(items[1].quantity, isNull);
    expect(items[1].unit, isNull);
    expect(items[1].category, 'ostalo');
    expect(items[2].quantity, isNull);
  });

  test('preskače nevažeće stavke', () {
    final items = photoItemsFromAiResponse({
      'items': [
        'tekst',
        {'name': ''},
        {'quantity': 2},
        {'name': 'jaje'},
      ],
    });
    expect(items.map((i) => i.name), ['jaje']);
  });

  test('odgovor bez ispravnih stavki traži ispravku', () {
    expect(
      () => photoItemsFromAiResponse({
        'items': [
          {'name': ''},
        ],
      }),
      throwsFormatException,
    );
    expect(() => photoItemsFromAiResponse({}), throwsFormatException);
  });

  test('slika bez namirnica', () {
    expect(
      () => photoItemsFromAiResponse({'error': 'no_food'}),
      throwsA(isA<NoFoodOnPhotoException>()),
    );
  });

  test('ograničava broj stavki', () {
    final items = photoItemsFromAiResponse({
      'items': [
        for (var i = 0; i < maxPhotoItems + 30; i++) {'name': 'a$i'},
      ],
    });
    expect(items, hasLength(maxPhotoItems));
  });
}
