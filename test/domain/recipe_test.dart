import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';

// Blagi čitač sačuvanih recepata; stroga provera AI odgovora je u
// test/ai/ai_response_validator_test.dart.
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
      () => parse({'title': 'X', 'ingredients': <Object>[]}),
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

  group('čuvanje', () {
    final original = Recipe(
      id: 'r1',
      title: 'Sarma',
      servings: 6,
      prepMinutes: 180,
      ingredients: const [
        Ingredient(
          name: 'kupus',
          quantity: 1,
          unit: 'glavica',
          category: 'konzerve i tegle',
          note: 'kiseli',
        ),
      ],
      steps: const ['Umotati.'],
      source: RecipeSource.photo,
      imagePath: 'recipe_photos/r1.jpg',
      answeredBy: 'Gemini Pro',
      createdAt: DateTime.utc(2026, 10, 30, 12),
    );

    test('toJson/fromJson vraća isti recept', () {
      final copy = Recipe.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
      expect(copy.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
      expect(copy.source, RecipeSource.photo);
    });

    test('fromJson bez naziva baca FormatException', () {
      final json = original.toJson()..['title'] = '';
      expect(() => Recipe.fromJson(json), throwsFormatException);
    });

    test('copyWith menja samo zadata polja', () {
      final c = original.copyWith(title: 'Posna sarma');
      expect(c.title, 'Posna sarma');
      expect(c.imagePath, 'recipe_photos/r1.jpg');
      expect(c.servings, 6);
      expect(original.copyWith(clearPrepMinutes: true).prepMinutes, isNull);
    });
  });
  group('veza sastojka sa katalogom (#30)', () {
    const stored = {
      'name': 'Jaja',
      'quantity': 2,
      'unit': 'kom',
      'category': 'mlečni proizvodi i jaja',
      'note': null,
      'foodId': '00000000-0000-4000-8000-000000000001',
      'matchedKey': 'jaja',
      'linkSource': 'confirmed',
    };

    test('čitanje pa čuvanje bez gubitka', () {
      final i = Ingredient.fromJson(Map.of(stored));
      expect(i.link?.foodId, '00000000-0000-4000-8000-000000000001');
      expect(i.link?.matchedKey, 'jaja');
      expect(i.link?.linkSource, LinkSource.confirmed);
      final json = i.toJson();
      expect(json['foodId'], '00000000-0000-4000-8000-000000000001');
      expect(json['matchedKey'], 'jaja');
      expect(json['linkSource'], 'confirmed');
      expect(Ingredient.fromJson(json).link, i.link);
    });

    test('sastojak bez veze se čuva kao do sada', () {
      final i = Ingredient.fromJson({'name': 'So'});
      expect(i.link, isNull);
      expect(i.toJson().keys.toSet(), {
        'name',
        'quantity',
        'unit',
        'category',
        'note',
      });
    });

    test('neispravna veza se odbacuje, sastojak ostaje', () {
      for (final broken in <Map<String, dynamic>>[
        {...stored, 'foodId': 5},
        {...stored, 'matchedKey': '  '},
        {...stored, 'linkSource': 'ai'},
        Map.of(stored)..remove('linkSource'),
        Map.of(stored)..remove('foodId'),
      ]) {
        final i = Ingredient.fromJson(broken);
        expect(i.link, isNull, reason: broken.toString());
        expect(i.name, 'Jaja');
      }
    });

    test('razmaci oko vrednosti veze se skidaju', () {
      final i = Ingredient.fromJson({
        ...stored,
        'foodId': ' 00000000-0000-4000-8000-000000000001 ',
        'matchedKey': 'jaja ',
      });
      expect(i.link?.foodId, '00000000-0000-4000-8000-000000000001');
      expect(i.link?.matchedKey, 'jaja');
    });

    test('copyWith čuva vezu', () {
      final i = Ingredient.fromJson(Map.of(stored));
      final changed = i.copyWith(quantity: 3);
      expect(changed.quantity, 3);
      expect(changed.name, 'Jaja');
      expect(changed.link, i.link);
    });

    test('namerno uklanjanje veze čuva ključ kroz serijalizaciju', () {
      final unlinked = Ingredient.fromJson(Map.of(stored)).unlink();
      expect(unlinked.link, isNull);
      expect(unlinked.unlinkedKey, 'jaja');
      expect(Ingredient.fromJson(unlinked.toJson()).unlinkedKey, 'jaja');
      expect(unlinked.copyWith(quantity: 3).unlinkedKey, 'jaja');
    });
  });
}
