import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/features/recipes/ingredient_review_sheet.dart';

import '../../helpers/test_app.dart';

Future<List<String>> shopping(AppDatabase db) async => [
  for (final i in await db.select(db.shoppingItems).get())
    if (!i.isBought) '${i.name} ${i.quantity} ${i.unit}',
];

Future<void> openReview(WidgetTester tester) async {
  await tapButton(tester, 'Proveri sastojke');
  expect(find.text('Označi šta imaš kod kuće.'), findsOneWidget);
}

Finder inSheet(String text) => find.descendant(
  of: find.byType(IngredientReviewSheet),
  matching: find.text(text),
);

Finder checkboxOf(String text) => find.descendant(
  of: find.ancestor(
    of: find.text(text),
    matching: find.byType(CheckboxListTile),
  ),
  matching: find.byType(Checkbox),
);

void main() {
  for (final accessible in [false, true]) {
    testTavli('Otvori nabavku: pristupačna navigacija $accessible', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(accessibleNavigation: accessible);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpTavli(
        tester,
        location: '/recipes/r1',
        recipes: [sampleRecipe('r1', 'Sarma')],
      );
      await openReview(tester);
      await tapButton(tester, 'Dodaj u nabavku (2)');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Otvori'), accessible ? findsOneWidget : findsNothing);
      if (accessible) {
        await tester.tap(find.text('Otvori'));
        await tester.pumpAndSettle();
        expect(find.text('Recepti u nabavci'), findsOneWidget);
        expect(find.text('kupus'), findsOneWidget);
      }
    });
  }

  testTavli('recept bez koraka ulazi u nabavku sa tačnim količinama', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Užina').copyWith(steps: [])],
    );
    await openReview(tester);
    await tester.tap(find.text('biber'));
    await tester.pump();
    await tapButton(tester, 'Dodaj u nabavku (1)');
    expect(await shopping(app.db), ['kupus 500.0 g']);
  });

  testTavli('recept bez plana: pregled ne čuva ništa; dodaje se samo ono '
      'što fali, ponovo samo razlika', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
    );
    await openReview(tester);
    expect(inSheet('4 porcije'), findsOneWidget);
    expect(inSheet('0,5 kg kupus'), findsOneWidget);
    expect(await app.db.select(app.db.shoppingSources).get(), isEmpty);

    await tester.tap(find.byTooltip('Manje porcija'));
    await tester.tap(find.byTooltip('Manje porcija'));
    await tester.pump();
    expect(inSheet('2 porcije'), findsOneWidget);
    expect(inSheet('0,25 kg kupus'), findsOneWidget);
    await tester.tap(find.text('biber'));
    await tester.pump();
    await tapButton(tester, 'Dodaj u nabavku (1)');

    expect(find.text('Dodato u nabavku: 1'), findsOneWidget);
    expect(await shopping(app.db), ['kupus 250.0 g']);
    expect(await app.db.select(app.db.mealPlans).get(), isEmpty);
    expect(await app.titles(), ['Sarma']);

    // Ponovo: ista priprema, "imam" je zapamćen.
    await openReview(tester);
    expect(inSheet('2 porcije'), findsOneWidget);
    expect(tester.widget<Checkbox>(checkboxOf('biber')).value, isTrue);
    await tester.tap(find.text('biber'));
    await tester.pump();
    await tapButton(tester, 'Ažuriraj nabavku');
    expect(
      await shopping(app.db),
      unorderedEquals(['kupus 250.0 g', 'biber null null']),
    );
    expect(await app.db.select(app.db.shoppingSources).get(), hasLength(1));

    await tester.tap(find.text('Otvori'));
    await tester.pumpAndSettle();
    expect(find.text('Recepti u nabavci'), findsOneWidget);
    expect(find.text('Sarma'), findsOneWidget);
    expect(find.text('2 porcije · 2 sastojka za kupovinu'), findsOneWidget);
    expect(find.text('kupus'), findsOneWidget);
  });

  testTavli('"Ponovi nabavku" je nova priprema; stara ostaje istorija', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
    );
    await openReview(tester);
    await tester.tap(find.text('biber'));
    await tester.pump();
    await tapButton(tester, 'Dodaj u nabavku (1)');
    await openReview(tester);
    await tapButton(tester, 'Ponovi nabavku');

    final sources = await app.db.select(app.db.shoppingSources).get();
    expect(sources, hasLength(2));
    expect(sources.where((s) => s.supersededAt == null), hasLength(1));
    expect(await shopping(app.db), ['kupus 1.0 kg']);
  });

  testTavli('nesačuvan AI recept: provera i nabavka bez čuvanja u '
      'recepte', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Sarma'))],
    );
    await tester.enterText(textField('Naziv jela'), 'sarma');
    await tester.pump();
    await tapButton(tester, 'Napravi recept');
    await openReview(tester);
    expect(await app.db.select(app.db.shoppingSources).get(), isEmpty);
    await tapButton(tester, 'Dodaj u nabavku (2)');

    expect(await app.titles(), isEmpty);
    final source = (await app.db.select(app.db.shoppingSources).get()).single;
    expect(source.recipeId, isNull);
    expect(
      await shopping(app.db),
      unorderedEquals(['crni luk 500.0 g', 'biber null null']),
    );
    // Pregled je i dalje otvoren i može da se sačuva.
    expect(button('Sačuvaj'), findsOneWidget);
  });

  testTavli('recept u planu: nudi nabavku plana; dodavanje je posebna '
      'priprema', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
      setup: (db) async {
        final account = await db.select(db.accounts).getSingle();
        final day = CivilDate(2026, 11, 2).toWire();
        await db
            .into(db.mealPlans)
            .insert(
              MealPlansCompanion.insert(
                id: 'p1',
                startDate: day,
                endDate: day,
                mealTypesJson: '["lunch"]',
                createdAt: DateTime.utc(2026, 11),
                householdId: Value(account.householdId),
              ),
            );
        await db
            .into(db.mealPlanEntries)
            .insert(
              MealPlanEntriesCompanion.insert(
                id: 'e1',
                planId: 'p1',
                date: day,
                mealType: 'lunch',
                recipeId: const Value('r1'),
                householdId: Value(account.householdId),
              ),
            );
      },
    );
    await openReview(tester);
    expect(find.text('Ovaj recept je već u planu.'), findsOneWidget);
    await tapButton(tester, 'Pogledaj');
    expect(find.text('Po planu'), findsOneWidget);
    expect(find.text('Proveri sastojke'), findsNothing);
  });
  testTavli('dodavanje u nabavku sa drugim brojem porcija čuva vezu', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [
        Recipe(
          id: 'a',
          title: 'Kajgana',
          servings: 2,
          ingredients: const [
            Ingredient(
              name: 'jaja',
              quantity: 3,
              unit: 'kom',
              category: 'mlečni proizvodi i jaja',
              link: IngredientLink(
                foodId: '00000000-0000-4000-8000-000000000001',
                matchedKey: 'jaja',
                linkSource: LinkSource.confirmed,
              ),
            ),
          ],
          source: RecipeSource.manual,
          createdAt: DateTime.utc(2026),
        ),
      ],
    );
    await openReview(tester);
    await tester.tap(find.byTooltip('Više porcija'));
    await tester.pump();
    await tapButton(tester, 'Dodaj u nabavku (1)');

    final source = (await app.db.select(app.db.shoppingSources).get()).single;
    final snapshot = jsonDecode(source.recipeSnapshotJson!) as Map;
    final ingredient = (snapshot['ingredients'] as List).single as Map;
    expect(ingredient['foodId'], '00000000-0000-4000-8000-000000000001');
    expect(ingredient['linkSource'], 'confirmed');
  });
}
