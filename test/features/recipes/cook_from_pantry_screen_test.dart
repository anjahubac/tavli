import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

/// Namirnice u ostavi prijavljenog domaćinstva.
Future<void> Function(AppDatabase) pantry(List<String> names) => (db) async {
  final account = await db.select(db.accounts).getSingle();
  for (final (i, name) in names.indexed) {
    await db
        .into(db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            id: 'p$i',
            name: name,
            category: 'ostalo',
            addedAt: DateTime.utc(2026, 11, 20),
            householdId: Value(account.householdId),
          ),
        );
  }
};

Recipe withIngredients(String id, String title, List<String> names) =>
    sampleRecipe(
      id,
      title,
    ).copyWith(ingredients: [for (final n in names) Ingredient(name: n)]);

final recipes = [
  withIngredients('gibanica', 'Gibanica', ['kore', 'sir', 'jaja']),
  withIngredients('palacinke', 'Palačinke', [
    'jaja',
    'mleko',
    'brašno',
    'ulje',
    'so',
  ]),
  withIngredients('riba', 'Riba na žaru', ['riba', 'limun']),
];

/// Ikonica „Šta da skuvam?“ (lista recepata i Ostava na telefonu).
final pantryIcon = find.byWidgetPredicate(
  (w) => w is TavliIconButton && w.semanticLabel == 'Šta da skuvam?',
);

String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).last)).state.uri
        .toString();

void main() {
  testTavli('sa liste recepata: predlozi po tome koliko fali, pa recept', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      recipes: recipes,
      setup: pantry(['Jaja', 'Mleko', 'Brašno']),
    );

    await tester.tap(pantryIcon);
    await tester.pumpAndSettle();

    expect(find.text('Šta da skuvam?'), findsOneWidget);
    expect(
      find.text(
        'Iz onoga što imaš u ostavi. So, biber, ulje i voda se ne računaju.',
      ),
      findsOneWidget,
    );
    final palacinke = tester.getTopLeft(find.text('Palačinke')).dy;
    final gibanica = tester.getTopLeft(find.text('Gibanica')).dy;
    expect(palacinke, lessThan(gibanica));
    expect(find.text('Imaš sve · 45 min · 4 porcije'), findsOneWidget);
    expect(find.text('Fali 2: kore, sir'), findsOneWidget);
    // Recept bez ijednog sastojka iz ostave se ne prikazuje.
    expect(find.text('Riba na žaru'), findsNothing);

    await tester.tap(find.text('Gibanica'));
    await tester.pumpAndSettle();
    expect(location(tester), '/recipes/gibanica');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Fali 2: kore, sir'), findsOneWidget);
  });

  testTavli('prazna ostava: poruka i put do ostave', (tester) async {
    await pumpTavli(tester, location: '/recipes/from-pantry', recipes: recipes);

    expect(find.text('Ostava je prazna'), findsOneWidget);
    await tapButton(tester, 'Otvori ostavu');
    expect(location(tester), '/pantry');
  });

  testTavli('ništa iz ostave nije u receptima: poruka', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/from-pantry',
      recipes: recipes,
      setup: pantry(['Banane']),
    );
    expect(find.text('Nema recepta od onoga što imaš'), findsOneWidget);
  });

  testTavli('sa Ostave na telefonu: ikonica pored pretrage', (tester) async {
    await pumpTavli(
      tester,
      location: '/pantry',
      recipes: recipes,
      setup: pantry(['Jaja']),
    );
    await tester.tap(pantryIcon);
    await tester.pumpAndSettle();
    expect(location(tester), '/recipes/from-pantry');
    expect(find.text('Gibanica'), findsOneWidget);
  });

  testTavli('sa Ostave na računaru: dugme u zaglavlju', (tester) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/pantry',
      recipes: recipes,
      setup: pantry(['Jaja']),
    );
    await tapButton(tester, 'Šta da skuvam?');
    expect(location(tester), '/recipes/from-pantry');
  });

  for (final size in [const Size(320, 640), wide]) {
    testTavli('${size.width} px, tekst 2×: predlozi bez preliva', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: size,
        location: '/recipes/from-pantry',
        recipes: recipes,
        setup: pantry(['Jaja', 'Mleko']),
      );
      // Na uskom ekranu sa duplim tekstom red je ispod uvoda.
      await tester.scrollUntilVisible(
        find.text('Gibanica'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Fali 2: kore, sir'), findsOneWidget);
    });
  }
}
