import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

/// Sreda, 4. novembar 2026, podne.
DateTime fixedNow() => DateTime(2026, 11, 4, 12);

Finder inPanel(Finder f) => find.descendant(
  of: find.ancestor(
    of: find.text('Porcije'),
    matching: find.byWidgetPredicate((w) => w is TavliSheet || w is Dialog),
  ),
  matching: f,
);

Future<void> openPanel(WidgetTester tester) async {
  await tapButton(tester, 'Dodaj u plan');
  await tester.pumpAndSettle();
  expect(find.text('Porcije'), findsOneWidget);
}

Future<void> confirmAdd(WidgetTester tester) async {
  final add = inPanel(button('Dodaj u plan'));
  await tester.ensureVisible(add);
  await tester.tap(add);
  await tester.pumpAndSettle();
}

Future<List<String>> entries(AppDatabase db) async => [
  for (final e in await db.select(db.mealPlanEntries).get())
    '${e.mealType} ${e.recipeId} ${e.servings}',
];

void main() {
  testTavli('telefon: dodaje recept na prvo slobodno mesto danas i javlja '
      'da je nabavka osvežena', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
      overrides: [clockProvider.overrideWithValue(fixedNow)],
    );
    await openPanel(tester);

    expect(inPanel(find.text('Sarma')), findsOneWidget);
    expect(inPanel(find.text('Sreda, 4. novembar')), findsOneWidget);
    expect(inPanel(find.text('Slobodno')), findsNWidgets(5));

    await confirmAdd(tester);

    expect(
      find.text('Dodato u plan: sreda, ručak. Nabavka je osvežena.'),
      findsOneWidget,
    );
    expect(await entries(app.db), ['lunch r1 4']);
    expect(await app.db.select(app.db.shoppingItems).get(), isNotEmpty);
  });

  testTavli('zauzeto mesto: „Zadrži“ vraća izbor, „Zameni“ menja jelo', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma'), sampleRecipe('r2', 'Pasulj')],
      overrides: [clockProvider.overrideWithValue(fixedNow)],
    );
    await openPanel(tester);
    await confirmAdd(tester);

    // Poruka o dodavanju se skloni sama.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await openPanel(tester);
    // Ručak je zauzet, pa je predložena večera.
    expect(inPanel(find.text('Sarma')), findsWidgets);
    await tester.tap(inPanel(find.text('Ručak')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Zameniće: Sarma')), findsOneWidget);

    await confirmAdd(tester);
    expect(find.text('Ručak je već u planu'), findsOneWidget);
    await tester.tap(find.text('Zadrži'));
    await tester.pumpAndSettle();
    expect(find.text('Porcije'), findsOneWidget);
    expect(await entries(app.db), ['lunch r1 4']);

    final fewer = inPanel(iconButton('Manje porcija'));
    await tester.ensureVisible(fewer);
    await tester.pumpAndSettle();
    await tester.tap(fewer);
    await tester.pumpAndSettle();
    await confirmAdd(tester);
    await tester.tap(find.text('Zameni'));
    await tester.pumpAndSettle();

    expect(await entries(app.db), ['lunch r1 3']);
    expect(find.textContaining('Dodato u plan: sreda, ručak.'), findsOneWidget);
  });

  testTavli('prošli dani se ne biraju; prethodna nedelja je zatvorena', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
      overrides: [clockProvider.overrideWithValue(fixedNow)],
    );
    await openPanel(tester);

    await tester.tap(inPanel(find.text('2')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Sreda, 4. novembar')), findsOneWidget);

    await tester.tap(inPanel(iconButton('Sledeća nedelja')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Ponedeljak, 9. novembar')), findsOneWidget);
    await tester.tap(inPanel(iconButton('Prethodna nedelja')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Sreda, 4. novembar')), findsOneWidget);
  });

  for (final (name, size) in [('telefon', phone), ('širok ekran', wide)]) {
    testTavli('$name: tri dugmeta iste visine, tekst u jednom redu', (
      tester,
    ) async {
      await pumpTavli(
        tester,
        size: size,
        location: '/recipes/r1',
        recipes: [sampleRecipe('r1', 'Sarma')],
        overrides: [clockProvider.overrideWithValue(fixedNow)],
      );
      final height = tester.getSize(button('Kuvaj')).height;
      final line = tester.getSize(find.text('Kuvaj')).height;
      for (final t in ['Dodaj u plan', 'Proveri sastojke']) {
        expect(tester.getSize(button(t)).height, height);
        expect(tester.getSize(find.text(t)).height, line);
      }
    });
  }

  testTavli('širok ekran: izbor je u dijalogu, ne u donjem listu', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/recipes/r1',
      recipes: [sampleRecipe('r1', 'Sarma')],
      overrides: [clockProvider.overrideWithValue(fixedNow)],
    );
    await openPanel(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(TavliSheet), findsNothing);
  });
}
