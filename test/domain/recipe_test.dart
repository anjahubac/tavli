import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';

Recipe parse(Map<String, dynamic> json) => Recipe.fromAiJson(
  json,
  id: 'r1',
  source: RecipeSource.ai,
  createdAt: DateTime(2026),
);

void main() {
  test('čita kompletan recept', () {
    final r = parse({
      'title': 'Sarma',
      'servings': 6,
      'prepMinutes': 180,
      'ingredients': [
        {
          'name': 'kiseli kupus',
          'quantity': 1,
          'unit': 'glavica',
          'category': 'konzerve i tegle',
        },
        {
          'name': 'mleveno meso',
          'quantity': '0,5',
          'unit': 'kg',
          'category': 'meso i riba',
        },
        {
          'name': 'biber',
          'quantity': null,
          'unit': '',
          'category': 'začini i sosovi',
          'note': 'po ukusu',
        },
      ],
      'steps': ['Umotati sarme.', ' ', 'Kuvati 3 sata.'],
    });

    expect(r.title, 'Sarma');
    expect(r.servings, 6);
    expect(r.ingredients[1].quantity, 0.5);
    expect(r.ingredients[2].unit, isNull);
    expect(r.steps, ['Umotati sarme.', 'Kuvati 3 sata.']);
    expect(r.detailLevel, DetailLevel.full);
  });

  test('razlomak i nepoznata kategorija', () {
    final r = parse({
      'title': 'Palačinke',
      'ingredients': [
        {
          'name': 'šećer',
          'quantity': '1/2',
          'unit': 'šolja',
          'category': 'slatkiši',
        },
      ],
    });

    expect(r.ingredients.single.quantity, 0.5);
    expect(r.ingredients.single.category, 'ostalo');
    expect(r.servings, 2);
    expect(r.detailLevel, DetailLevel.summary);
  });

  test('recept bez naziva ili sastojaka je FormatException', () {
    expect(
      () => parse({
        'title': '',
        'ingredients': [
          {'name': 'x'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => parse({'title': 'X', 'ingredients': []}),
      throwsFormatException,
    );
    expect(
      () => parse({
        'title': 'X',
        'ingredients': [
          {'name': ' '},
        ],
      }),
      throwsFormatException,
    );
  });

  test('toAiJson -> fromAiJson zadržava sadržaj', () {
    final r = parse({
      'title': 'Pasulj',
      'servings': 4,
      'ingredients': [
        {
          'name': 'pasulj',
          'quantity': 500,
          'unit': 'g',
          'category': 'suvi proizvodi',
        },
      ],
      'steps': ['Potopiti preko noći.'],
    });

    final copy = parse(r.toAiJson());
    expect(copy.toAiJson(), r.toAiJson());
  });
}
