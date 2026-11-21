import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_response_validator.dart';
import 'package:tavli/ai/ai_units.dart';
import 'package:tavli/ai/meal_plan_ai.dart';
import 'package:tavli/ai/meal_plan_prompts.dart';
import 'package:tavli/ai/prompts.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_labels.dart';
import 'package:tavli/domain/shopping_source.dart';

const fixtureDir = 'specs/014-ai-response-contracts/contracts/fixtures';

Recipe parse(Map<String, dynamic> json) => recipeFromAiResponse(
  json,
  id: 'r1',
  source: RecipeSource.photo,
  createdAt: DateTime(2026),
);

/// Vrednost iz recepta po putanji iz primera, npr. `ingredients[2].unit`.
Object? recipeValue(Recipe r, String path) {
  final m = RegExp(r'^ingredients\[(\d+)\]\.(\w+)$').firstMatch(path);
  if (m != null) {
    final i = r.ingredients[int.parse(m[1]!)];
    return switch (m[2]) {
      'name' => i.name,
      'quantity' => i.quantity,
      'unit' => i.unit,
      'category' => i.category,
      'note' => i.note,
      'unitCanonical' => canonicalUnit(i.unit),
      'unitStatus' =>
        i.unit == null
            ? 'none'
            : canonicalUnit(i.unit) == null
            ? 'unknown'
            : 'known',
      _ => throw ArgumentError(path),
    };
  }
  return switch (path) {
    'title' => r.title,
    'servings' => r.servings,
    'prepMinutes' => r.prepMinutes,
    'detailLevel' => r.detailLevel.name,
    'steps.length' => r.steps.length,
    _ => throw ArgumentError(path),
  };
}

List<MealSlot> slotsOf(Map<String, dynamic> request) => [
  for (final s in request['slots'] as List<dynamic>)
    MealSlot(
      CivilDate.parse((s as Map<String, dynamic>)['date'] as String),
      MealType.tryParse(s['meal'])!,
    ),
];

/// Pušta odgovor iz primera kroz proveru za njegov ugovor.
Object runFixture(Map<String, dynamic> f) {
  final response = f['response'] as Map<String, dynamic>;
  final request = f['request'] as Map<String, dynamic>? ?? const {};
  switch (f['contract']) {
    case 'recipe.v1':
      // R11 obrađuje RecipeAI.fromImage pre provere oblika.
      if (response['error'] == 'not_a_recipe') return 'not_a_recipe';
      return parse(response);
    case 'plan-outline.v1':
      return parseOutline(
        response,
        slots: slotsOf(request),
        library: {
          for (final r in request['library'] as List<dynamic>)
            (r as Map<String, dynamic>)['id'] as String: r['title'] as String,
        },
      );
    case 'recipe-summary.v1':
      return parseSummaries(
        response,
        titles: [for (final t in request['titles'] as List<dynamic>) '$t'],
      );
  }
  throw ArgumentError(f['contract']);
}

void checkExpected(Map<String, dynamic> f, Object result) {
  final expected = f['expected'] as Map<String, dynamic>? ?? const {};
  for (final MapEntry(:key, :value) in expected.entries) {
    final Object? actual;
    if (result is Recipe) {
      actual = recipeValue(result, key);
    } else if (result is Map<MealSlot, SlotProposal>) {
      final [slot, field] = key.split('.');
      final p = result.entries
          .firstWhere((e) => '${e.key.date}/${e.key.type.name}' == slot)
          .value;
      actual = field == 'title' ? p.title : p.libraryRecipeId;
    } else {
      final dot = key.indexOf('.');
      final title = key.substring(0, dot);
      final path = key.substring(dot + 1);
      final s = (result as Map<String, RecipeSnapshot>)[draftRecipeKey(title)]!;
      actual = path == 'baseServings'
          ? s.baseServings
          : recipeValue(
              Recipe(
                id: 'x',
                title: s.title,
                servings: s.baseServings,
                ingredients: s.ingredients,
                source: RecipeSource.ai,
                createdAt: DateTime(2026),
              ),
              path,
            );
    }
    expect(actual, value, reason: '${f['why']} ($key)');
  }
}

void main() {
  group('primeri iz ugovora', () {
    final files = [
      for (final dir in ['valid', 'invalid'])
        ...Directory('$fixtureDir/$dir').listSync().whereType<File>(),
    ]..sort((a, b) => a.path.compareTo(b.path));

    // Folder nije prazan, pa testovi ispod nisu prazni; broj primera se
    // ne zaključava, da novi primer ne obori ovaj test.
    test('primeri su učitani iz oba foldera', () {
      for (final dir in ['valid', 'invalid']) {
        expect(
          files.where((f) => f.parent.path.endsWith(dir)),
          isNotEmpty,
          reason: dir,
        );
      }
    });

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final f = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      test('$name: ${f['expect']}', () {
        switch (f['expect']) {
          case 'accept':
            checkExpected(f, runFixture(f));
          case 'not_a_recipe':
            expect(runFixture(f), 'not_a_recipe');
          case 'reject':
            expect(
              () => runFixture(f),
              throwsFormatException,
              reason: f['why'] as String,
            );
            // Recept i sažeci nose oznaku pravila za #42 (popravku).
            if (f['contract'] != 'plan-outline.v1') {
              final rule = (f['rule'] as String).split(',').first.trim();
              expect(
                () => runFixture(f),
                throwsA(
                  isA<FormatException>().having((e) => e.message, 'rule', rule),
                ),
              );
            }
          default:
            fail('nepoznat ishod ${f['expect']}');
        }
      });
    }
  });

  group('recipe.v1 granice', () {
    Map<String, dynamic> recipe({
      Object? servings = 4,
      Map<String, dynamic>? ingredient,
      Object? steps,
      String title = 'Supa',
    }) => {
      'title': title,
      'servings': servings,
      'ingredients': [
        ingredient ?? {'name': 'voda', 'quantity': 1, 'unit': 'l'},
      ],
      'steps': ?steps,
    };

    String? rule(Map<String, dynamic> json) {
      try {
        parse(json);
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    }

    test('porcije: ceo broj 1–99', () {
      expect(parse(recipe(servings: 99)).servings, 99);
      expect(parse(recipe(servings: 4.0)).servings, 4);
      expect(rule(recipe(servings: 100)), 'R2');
      expect(rule(recipe(servings: 2.5)), 'R2');
      expect(rule(recipe(servings: -1)), 'R2');
    });

    test('naziv: 1–120 znakova, bez razmaka sa krajeva', () {
      expect(parse(recipe(title: 'a' * 120)).title, hasLength(120));
      expect(rule(recipe(title: 'a' * 121)), 'R1');
      expect(rule(recipe(title: '   ')), 'R1');
      expect(rule({...recipe(), 'title': 7}), 'R1');
    });

    test('sastojci: najviše 60, svaki je objekat', () {
      final many = {
        ...recipe(),
        'ingredients': [
          for (var i = 0; i < 61; i++) {'name': 'x$i'},
        ],
      };
      expect(rule(many), 'R4');
      expect(
        rule({
          ...recipe(),
          'ingredients': ['so'],
        }),
        'R4',
      );
    });

    test('količina: broj veći od nule ili null', () {
      expect(
        parse(recipe(ingredient: {'name': 'so', 'quantity': null}))
            .ingredients
            .single
            .quantity,
        isNull,
      );
      expect(
        parse(recipe(ingredient: {'name': 'so'})).ingredients.single.quantity,
        isNull,
      );
      double? quantity(num v) =>
          parse(recipe(ingredient: {'name': 'so', 'quantity': v}))
              .ingredients
              .single
              .quantity;
      expect(quantity(minQuantity), minQuantity);
      expect(quantity(maxQuantity), maxQuantity);
      for (final bad in [0, 0.0009, 100001, 1e300, '0,5', 'malo', true]) {
        expect(
          rule(recipe(ingredient: {'name': 'so', 'quantity': bad})),
          'R6',
          reason: '$bad',
        );
      }
    });

    test('jedinica, naziv i napomena: tip i dužina', () {
      expect(rule(recipe(ingredient: {'name': 'so', 'unit': 'x' * 31})), 'R7');
      expect(rule(recipe(ingredient: {'name': 'a' * 81})), 'R5');
      expect(rule(recipe(ingredient: {'name': 'so', 'note': 'x' * 201})), 'R9');
      expect(rule(recipe(ingredient: {'name': 'so', 'note': 3})), 'R9');
      final blank = parse(
        recipe(ingredient: {'name': ' so ', 'unit': ' ', 'note': ''}),
      ).ingredients.single;
      expect(blank.name, 'so');
      expect(blank.unit, isNull);
      expect(blank.note, isNull);
    });

    test('nepoznata jedinica ostaje kako je napisana', () {
      final i = parse(
        recipe(ingredient: {'name': 'kafa', 'quantity': 1, 'unit': 'Fildžan'}),
      ).ingredients.single;
      expect(i.unit, 'Fildžan');
      expect(canonicalUnit(i.unit), isNull);
    });

    test('koraci: lista teksta, najviše 40, svaki do 1000 znakova', () {
      expect(parse(recipe()).steps, isEmpty);
      expect(parse({...recipe(), 'steps': null}).steps, isEmpty);
      expect(rule(recipe(steps: 'Skuvati.')), 'R10');
      expect(rule(recipe(steps: [1])), 'R10');
      expect(rule(recipe(steps: ['x' * 1001])), 'R10');
      expect(rule(recipe(steps: [for (var i = 0; i < 41; i++) 'k$i'])), 'R10');
      expect(
        parse(recipe(steps: [for (var i = 0; i < 40; i++) 'k$i', ' '])).steps,
        hasLength(40),
      );
    });

    test('vreme pripreme: pozitivan broj ili null', () {
      int? prep(Object? v) =>
          parse({...recipe(), 'prepMinutes': v}).prepMinutes;
      expect(prep(29.6), 30);
      expect(prep(0), isNull);
      expect(prep(-5), isNull);
      expect(prep(0.2), isNull);
      expect(prep('30'), isNull);
      expect(prep(2880), 2880, reason: 'testo odstoji 48 h');
      expect(prep(maxPrepMinutes), maxPrepMinutes);
      expect(prep(maxPrepMinutes + 1), isNull);
      expect(prep(1e12), isNull);
    });
  });

  group('oznake recepta (L1–L3)', () {
    test('poznate oznake se čitaju, izvor je ai', () {
      final l = aiLabels({
        'meals': ['Dinner', 'lunch', 'lunch'],
        'weight': 'hearty',
        'dishKind': 'baked_fried',
      });
      expect(l.meals, ['lunch', 'dinner'], reason: 'redom dana, bez duplikata');
      expect(l.weightValue, DishWeight.hearty);
      expect(l.dishKindValue, DishKind.bakedFried);
      expect(l.sourceValue, LabelsSource.ai);
    });

    test('nepoznata vrednost postaje prazna, recept se ne odbija', () {
      final l = aiLabels({
        'meals': ['brunch', 7, 'snack'],
        'weight': 'ogromno',
        'dishKind': 'roast',
      });
      expect(l.mealSet, {MealSuitability.snack});
      expect(l.weight, isNull);
      expect(l.dishKind, isNull);
      expect(
        parse({
          'title': 'Pasulj',
          'servings': 4,
          'ingredients': [
            {'name': 'pasulj'},
          ],
          'meals': 'lunch',
          'weight': 3,
        }).labels,
        RecipeLabels.none,
      );
    });

    test('bez ijedne poznate oznake recept ostaje neoznačen', () {
      expect(aiLabels(const {}), RecipeLabels.none);
      expect(aiLabels(const {'meals': <Object?>[]}).source, isNull);
    });

    test('obe užine iz plana odgovaraju oznaci užina', () {
      expect(suitabilityFor(MealType.morningSnack), MealSuitability.snack);
      expect(suitabilityFor(MealType.afternoonSnack), MealSuitability.snack);
      expect(suitabilityFor(MealType.lunch), MealSuitability.lunch);
      expect(suitabilityFor(MealType.breakfast), MealSuitability.breakfast);
      expect(suitabilityFor(MealType.dinner), MealSuitability.dinner);
    });
  });

  group('naziv sastojka za katalog (TRELLO-40)', () {
    test('zagrada iz naziva prelazi u napomenu', () {
      final i = aiIngredient({'name': 'paradajz (oljušten)', 'quantity': 2});
      expect(i.name, 'paradajz');
      expect(i.note, 'oljušten');
    });

    test('zagrada se dodaje ispred postojeće napomene', () {
      final i = aiIngredient({
        'name': 'crni luk (srednji)',
        'note': 'sitno iseckan',
      });
      expect(i.name, 'crni luk');
      expect(i.note, 'srednji, sitno iseckan');
    });

    test('naziv bez zagrade ili samo zagrada ostaje kakav je', () {
      expect(aiIngredient({'name': 'kiselo mleko'}).name, 'kiselo mleko');
      expect(aiIngredient({'name': '(so)'}).name, '(so)');
      expect(
        aiIngredient({'name': 'paprika (crvena) iseckana'}).name,
        'paprika (crvena) iseckana',
      );
    });

    test('preduga napomena: naziv ostaje, odgovor se ne odbija', () {
      final note = 'a' * (maxNoteLength - 3);
      final i = aiIngredient({'name': 'so (morska)', 'note': note});
      expect(i.name, 'so (morska)');
      expect(i.note, note);
    });

    test('upiti za recept i plan nose pravila za naziv', () {
      for (final prompt in [recipeSystemPrompt, mealPlanSystemPrompt]) {
        expect(prompt, contains(ingredientNameRules));
      }
      expect(ingredientNameRules, contains('"so i biber" is two ingredients'));
      expect(ingredientNameRules, contains('nominative singular'));
    });
  });

  group('rečnik jedinica', () {
    test('množina, skraćenice i velika slova', () {
      expect(canonicalUnit('Kašike'), 'kašika');
      expect(canonicalUnit(' čaše '), 'čaša');
      expect(canonicalUnit('kom.'), 'kom');
      expect(canonicalUnit('grama'), 'g');
      expect(canonicalUnit('dl'), 'dl');
      expect(canonicalUnit('kafena šolja'), isNull);
      expect(canonicalUnit(null), isNull);
    });

    test('promptovi traže iste jedinice koje provera prepoznaje', () {
      for (final prompt in [
        recipeSystemPrompt,
        recipeSummariesPrompt(['X']),
      ]) {
        expect(prompt, contains(aiUnitList));
      }
      expect(aiUnitList, contains('čaša'));
    });

    test('svaki oblik pripada samo jednoj jedinici', () {
      final seen = <String, String>{};
      for (final MapEntry(:key, :value) in aiUnitVocabulary.entries) {
        for (final form in {key, ...value}) {
          expect(seen[form], anyOf(isNull, key), reason: form);
          seen[form] = key;
        }
      }
    });
  });
  test('AI ne može da postavi vezu sastojka', () {
    final i = aiIngredient({
      'name': 'jaja',
      'quantity': 2,
      'unit': 'kom',
      'foodId': '00000000-0000-4000-8000-000000000001',
      'matchedKey': 'jaja',
      'linkSource': 'confirmed',
    });
    expect(i.link, isNull);
  });
}
