import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/pantry_suggestions.dart';
import 'package:tavli/domain/recipe.dart';

Ingredient item(String name, {String? foodId}) => Ingredient(
  name: name,
  link: foodId == null
      ? null
      : IngredientLink(
          foodId: foodId,
          matchedKey: name,
          linkSource: LinkSource.matched,
        ),
);

Recipe recipe(String id, List<Ingredient> ingredients, {String? title}) =>
    Recipe(
      id: id,
      title: title ?? id,
      servings: 4,
      ingredients: ingredients,
      steps: const ['Skuvaj.'],
      source: RecipeSource.manual,
      createdAt: DateTime.utc(2026),
    );

PantryFood food(String name, {String? foodId, double? quantity}) =>
    (name: name, foodId: foodId, quantity: quantity);

List<String> ids(List<PantrySuggestion> s) => [for (final x in s) x.recipe.id];

void main() {
  test('ostava od 10 namirnica: prvi je recept kome fali najmanje', () {
    final pantry = [
      for (final n in [
        'jaja',
        'mleko',
        'brašno',
        'crni luk',
        'krompir',
        'sir',
        'paradajz',
        'pirinač',
        'šargarepa',
        'pavlaka',
      ])
        food(n),
    ];
    final recipes = [
      recipe('musaka', [
        item('krompir'),
        item('mleveno meso'),
        item('jaja'),
        item('mleko'),
        item('pavlaka'),
      ]),
      recipe('sarma', [
        item('kiseli kupus'),
        item('mleveno meso'),
        item('pirinač'),
        item('crni luk'),
      ]),
      recipe('palacinke', [
        item('jaja'),
        item('mleko'),
        item('brašno'),
        item('ulje'),
        item('so'),
      ]),
      recipe('gibanica', [
        item('kore'),
        item('sir'),
        item('jaja'),
        item('mleko'),
      ]),
    ];

    final s = suggestFromPantry(recipes, pantry);

    expect(ids(s), ['palacinke', 'musaka', 'gibanica', 'sarma']);
    expect(s.first.hasEverything, isTrue);
    expect(s.first.have, 3);
    expect(s[1].missing, ['mleveno meso']);
    expect(s.last.missing, ['kiseli kupus', 'mleveno meso']);
  });

  test('so, biber, ulje i voda se ne računaju ni kao imaš ni kao fali', () {
    final s = suggestFromPantry(
      [
        recipe('a', [
          item('jaja'),
          item('morska so'),
          item('crni biber'),
          item('maslinovo ulje'),
          item('voda'),
        ]),
        recipe('samo-osnovno', [item('so'), item('voda')]),
      ],
      [food('jaja'), food('so')],
    );
    expect(ids(s), ['a']);
    expect(s.single.have, 1);
    expect(s.single.missing, isEmpty);
    expect(isPantryStaple('sok od pomorandže'), isFalse);
    expect(isPantryStaple('sojin sos'), isFalse);
  });

  test('poklapanje po id-ju iz kataloga, a bez veze po nazivu', () {
    final s = suggestFromPantry(
      [
        recipe('po-id', [item('Crni luk, sitno', foodId: 'luk')]),
        recipe('po-nazivu', [item('  Pirinač ')]),
        recipe('nista', [item('tunjevina', foodId: 'tuna')]),
      ],
      [food('luk crni', foodId: 'luk'), food('pirinač')],
    );
    expect(ids(s), ['po-id', 'po-nazivu']);
  });

  test('recepti bez ijednog sastojka iz ostave se ne prikazuju', () {
    expect(
      suggestFromPantry(
        [
          recipe('a', [item('riba')]),
        ],
        [food('jaja')],
      ),
      isEmpty,
    );
  });

  test('prazna ostava ili potrošena namirnica (0) ne daje predloge', () {
    final recipes = [
      recipe('a', [item('jaja')]),
    ];
    expect(suggestFromPantry(recipes, const []), isEmpty);
    expect(suggestFromPantry(recipes, [food('jaja', quantity: 0)]), isEmpty);
    // Nepoznata količina znači da je namirnica tu.
    expect(suggestFromPantry(recipes, [food('jaja')]), hasLength(1));
    expect(
      suggestFromPantry(recipes, [food('jaja', quantity: 2)]),
      hasLength(1),
    );
  });

  test('isti sastojak dva puta u receptu se broji jednom', () {
    final s = suggestFromPantry(
      [
        recipe('a', [item('jaja'), item('jaja'), item('mleko'), item('mleko')]),
      ],
      [food('jaja')],
    );
    expect(s.single.have, 1);
    expect(s.single.missing, ['mleko']);
  });

  test('isti broj koji fali: više poklopljenih pa naziv', () {
    final s = suggestFromPantry(
      [
        recipe('b', [item('jaja'), item('riba')], title: 'Beta'),
        recipe('a', [item('jaja'), item('riba')], title: 'alfa'),
        recipe('c', [item('jaja'), item('mleko'), item('riba')], title: 'Ce'),
      ],
      [food('jaja'), food('mleko')],
    );
    expect(ids(s), ['c', 'a', 'b']);
  });
}
