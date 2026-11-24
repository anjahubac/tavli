import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_labels.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> send(WidgetTester tester, String text) async {
    // Poruka na dnu ekrana (SnackBar) ne sme da prekrije polje za unos.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Šta da promenim?'),
      text,
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Pošalji'));
    await tester.pumpAndSettle();
  }

  testTavli('predlog → Prihvati menja recept i čuva istoriju', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [aiAnswer(recipeJson('Posna sarma'))],
    );

    await send(tester, 'posno');

    expect(app.adapter.requests.single.data.toString(), contains('posno'));
    expect(find.text('Predlog izmene'), findsOneWidget);
    expect(await app.titles(), ['Sarma']);

    await tapButton(tester, 'Prihvati');

    expect(await app.titles(), ['Posna sarma']);
    expect(find.text('Izmena je sačuvana.'), findsOneWidget);
    expect(find.text('posno'), findsOneWidget);
    expect(find.textContaining('Gemini Pro · '), findsOneWidget);
    final version = await app.db.select(app.db.recipeVersions).getSingle();
    expect(version.changeKind, 'ai');
    expect(version.instruction, 'posno');
    expect(version.changedBy, 'Gemini Pro');

    await tester.tap(find.byTooltip('Poništi poslednju izmenu'));
    await tester.pumpAndSettle();
    expect(await app.titles(), ['Sarma']);
    expect(find.text('Izmena je poništena.'), findsOneWidget);
    expect(await app.db.select(app.db.recipeVersions).get(), isEmpty);
  });

  testTavli('izmena bez koraka ne briše korake: pita ponovo, pa '
      'prihvata odgovor sa koracima', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [
        aiAnswer({...recipeJson('Posna sarma'), 'steps': null}),
        aiAnswer(recipeJson('Posna sarma')),
      ],
    );

    await send(tester, 'posno');

    expect(app.adapter.requests, hasLength(2));
    await tapButton(tester, 'Prihvati');
    final saved = await app.db.select(app.db.recipes).getSingle();
    expect(saved.stepsJson, contains('Kuvati.'));
  });

  testTavli('izmena koja stalno gubi korake ne menja recept', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [
        aiAnswer({...recipeJson('Posna sarma'), 'steps': <String>[]}),
        aiAnswer({...recipeJson('Posna sarma'), 'steps': <String>[]}),
      ],
    );

    await send(tester, 'posno');

    expect(find.text(invalidAnswer), findsOneWidget);
    expect(find.text('Predlog izmene'), findsNothing);
    expect(await app.titles(), ['Sarma']);
    final saved = await app.db.select(app.db.recipes).getSingle();
    expect(saved.stepsJson, contains('Umotati.'));
  });

  testTavli('Pokušaj ponovo šalje isto uputstvo i daje predlog', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [
        aiAnswer({...recipeJson('Posna sarma'), 'steps': <String>[]}),
        aiAnswer({...recipeJson('Posna sarma'), 'steps': <String>[]}),
        aiAnswer(recipeJson('Posna sarma')),
      ],
    );

    await send(tester, 'posno');
    expect(find.text(invalidAnswer), findsOneWidget);
    // Korisnik je u međuvremenu promenio tekst u polju.
    await tester.enterText(
      find.widgetWithText(TextField, 'Šta da promenim?'),
      'nešto drugo',
    );
    await tester.pump();

    await tapButton(tester, 'Pokušaj ponovo');

    expect(find.text(invalidAnswer), findsNothing);
    expect(find.text('Predlog izmene'), findsOneWidget);
    expect(app.adapter.requests, hasLength(3));
    expect(
      app.adapter.requests.last.data.toString(),
      allOf(contains('posno'), isNot(contains('nešto drugo'))),
      reason: 'uputstvo koje nije uspelo, ne tekst iz polja',
    );
    expect(
      find.widgetWithText(TextField, 'nešto drugo'),
      findsOneWidget,
      reason: 'novi tekst ostaje u polju',
    );
  });

  testTavli('AI izmena ne menja oznake koje je postavio korisnik', (
    tester,
  ) async {
    final user = RecipeLabels.byUser(
      meals: {MealSuitability.lunch},
      weight: DishWeight.medium,
    );
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma').copyWith(labels: user)],
      ai: [
        aiAnswer({
          ...recipeJson('Posna sarma'),
          'meals': ['dinner'],
          'weight': 'light',
        }),
      ],
    );

    await send(tester, 'posno');
    await tapButton(tester, 'Prihvati');

    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.title, 'Posna sarma');
    expect(row.mealTypesJson, '["lunch"]');
    expect(row.weight, 'medium');
    expect(row.labelsSource, 'user');
  });

  testTavli('Odbaci ne menja recept i vraća tekst u polje', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [aiAnswer(recipeJson('Posna sarma'))],
    );

    await send(tester, 'posno');
    await tapButton(tester, 'Odbaci');

    expect(await app.titles(), ['Sarma']);
    expect(await app.db.select(app.db.recipeVersions).get(), isEmpty);
    expect(find.widgetWithText(TextField, 'posno'), findsOneWidget);
  });

  testTavli('greška AI-ja: poruka, tekst ostaje, recept isti', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Sarma')],
      ai: [(401, '{}', {})],
    );

    await send(tester, 'posno');

    expect(
      find.text('Nijedan model nije dostupan. Proveri ključeve.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'posno'), findsOneWidget);
    expect(await app.titles(), ['Sarma']);
  });

  testTavli('vraćanje starije verzije iz liste verzija', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [sampleRecipe('a', 'Prva')],
      ai: [aiAnswer(recipeJson('Druga')), aiAnswer(recipeJson('Treća'))],
    );
    await send(tester, 'druga');
    await tapButton(tester, 'Prihvati');
    await send(tester, 'treća');
    await tapButton(tester, 'Prihvati');
    expect(await app.titles(), ['Treća']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Prethodne verzije'));
    await tester.pumpAndSettle();
    expect(find.text('AI izmena: „druga“'), findsOneWidget);
    expect(find.text('AI izmena: „treća“'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'AI izmena: „druga“'),
        matching: find.text('Vrati'),
      ),
    );
    await tester.pumpAndSettle();

    expect(await app.titles(), ['Prva']);
    expect(find.textContaining('Vraćena je verzija od'), findsOneWidget);

    // I vraćanje se može poništiti.
    await tester.tap(find.byTooltip('Poništi poslednju izmenu'));
    await tester.pumpAndSettle();
    expect(await app.titles(), ['Treća']);
  });
  testTavli('izmena preko četa čuva vezu nepromenjenog sastojka', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a/chat',
      recipes: [
        Recipe(
          id: 'a',
          title: 'Kajgana',
          servings: 2,
          ingredients: const [
            Ingredient(
              name: 'crni luk',
              quantity: 0.5,
              unit: 'kg',
              category: 'voće i povrće',
              link: IngredientLink(
                foodId: '00000000-0000-4000-8000-000000000001',
                matchedKey: 'crni luk',
                linkSource: LinkSource.confirmed,
              ),
            ),
          ],
          steps: const ['Iseckati luk.'],
          source: RecipeSource.manual,
          createdAt: DateTime.utc(2026),
        ),
      ],
      ai: [aiAnswer(recipeJson('Kajgana sa biberom'))],
    );

    await send(tester, 'dodaj biber');
    await tapButton(tester, 'Prihvati');

    final row = await app.db.select(app.db.recipes).getSingle();
    final stored = [
      for (final i in jsonDecode(row.ingredientsJson) as List) i as Map,
    ];
    final onion = stored.firstWhere((i) => i['name'] == 'crni luk');
    expect(onion['foodId'], '00000000-0000-4000-8000-000000000001');
    expect(onion['linkSource'], 'confirmed');
    expect(stored.firstWhere((i) => i['name'] == 'biber')['foodId'], isNull);
  });
}
