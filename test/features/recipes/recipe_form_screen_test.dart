import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => textField(label);

  Future<void> addIngredient(
    WidgetTester tester, {
    required String name,
    String quantity = '',
    String unit = '',
  }) async {
    await tapButton(tester, 'Dodaj sastojak');
    final dialog = find.byType(AlertDialog);
    Finder dialogField(String label) => find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextField, label),
    );
    await tester.enterText(dialogField('Naziv'), name);
    await tester.enterText(dialogField('Količina'), quantity);
    await tester.enterText(dialogField('Jedinica'), unit);
    await tester.pump();
    await tester.tap(find.descendant(of: dialog, matching: button('Sačuvaj')));
    await tester.pumpAndSettle();
  }

  testTavli('telefon: porcije i minuti stoje jedno pored drugog', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/recipes/new/manual');
    final servings = tester.getTopLeft(find.text('Broj porcija'));
    final prep = tester.getTopLeft(find.text('Vreme pripreme (min)'));
    expect(prep.dy, servings.dy);
    expect(tester.takeException(), isNull);
  });

  testTavli('tekst 2×: polja jedno ispod drugog, nazivi se ne seku', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(tester, location: '/recipes/new/manual');
    final servings = tester.getRect(find.text('Broj porcija'));
    final prep = tester.getRect(find.text('Vreme pripreme (min)'));
    expect(prep.top, greaterThan(servings.bottom));
    expect(tester.takeException(), isNull);
  });

  testTavli('bez naziva i sastojaka ništa se ne čuva', (tester) async {
    final app = await pumpTavli(tester, location: '/recipes/new/manual');

    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Unesi naziv recepta.'), findsOneWidget);
    expect(find.text('Dodaj bar jedan sastojak.'), findsOneWidget);
    expect(await app.titles(), isEmpty);
  });

  testTavli('ručni unos novog recepta', (tester) async {
    final app = await pumpTavli(tester, location: '/recipes/new/manual');

    await tester.enterText(field('Naziv'), 'Kajgana');
    await tester.enterText(field('Broj porcija'), '1');
    await tester.enterText(field('Vreme pripreme (min)'), '10');
    await addIngredient(tester, name: 'jaja', quantity: '3', unit: 'kom');
    await addIngredient(tester, name: 'mleko', quantity: '0,5', unit: 'dl');
    expect(find.text('0,5 dl mleko'), findsOneWidget);
    await tester.enterText(
      field('Koraci pripreme (jedan po redu)'),
      'Umutiti jaja.\n\nPeći.',
    );
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.title, 'Kajgana');
    expect(row.servings, 1);
    expect(row.prepMinutes, 10);
    expect(row.source, 'manual');
    expect(row.stepsJson, '["Umutiti jaja.","Peći."]');
    expect(find.widgetWithText(AppBar, 'Kajgana'), findsOneWidget);
    expect(find.text('Ručno unet'), findsOneWidget);
  });

  testTavli('ručni obrok bez koraka može da se sačuva i doda u nabavku', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/recipes/new/manual');
    await tester.enterText(field('Naziv'), 'Užina');
    await addIngredient(tester, name: 'jogurt', quantity: '200', unit: 'ml');
    await tapButton(tester, 'Sačuvaj');

    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.stepsJson, '[]');
    expect(find.widgetWithText(AppBar, 'Užina'), findsOneWidget);
    await tapButton(tester, 'Proveri sastojke');
    await tapButton(tester, 'Dodaj u nabavku (1)');

    final item = await app.db.select(app.db.shoppingItems).getSingle();
    expect(item.name, 'jogurt');
    expect(item.quantity, 200);
    expect(item.unit, 'ml');
  });

  testTavli('izmena čuva prethodnu verziju kao ručnu izmenu', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );

    await tester.tap(iconButton('Izmeni'));
    await tester.pumpAndSettle();
    expect(find.text('Izmeni recept'), findsOneWidget);
    await tester.enterText(field('Naziv'), 'Posna sarma');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(await app.titles(), ['Posna sarma']);
    final version = await app.db.select(app.db.recipeVersions).getSingle();
    expect(version.changeKind, 'manual');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(iconButton('Još opcija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prethodne verzije'));
    await tester.pumpAndSettle();
    expect(find.text('Ručna izmena'), findsOneWidget);
  });

  testTavli('izlazak sa nesačuvanim izmenama pita za potvrdu', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    await tester.tap(iconButton('Izmeni'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Naziv'), 'Nešto drugo');
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Odbaciti izmene?'), findsOneWidget);

    await tester.tap(find.text('Nastavi uređivanje'));
    await tester.pumpAndSettle();
    expect(find.text('Izmeni recept'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odbaci'));
    await tester.pumpAndSettle();
    expect(find.text('Izmeni recept'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Sarma'), findsOneWidget);
  });

  testTavli('brisanje uz potvrdu', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );

    await tester.tap(iconButton('Još opcija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši recept'));
    await tester.pumpAndSettle();
    expect(find.text('Obrisati „Sarma“?'), findsOneWidget);

    await tester.tap(find.text('Otkaži'));
    await tester.pumpAndSettle();
    expect(await app.titles(), ['Sarma']);

    await tester.tap(iconButton('Još opcija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši recept'));
    await tester.pumpAndSettle();
    await tester.tap(button('Obriši'));
    await tester.pumpAndSettle();

    expect(await app.titles(), isEmpty);
    expect(find.text('Recept je obrisan.'), findsOneWidget);
    expect(find.text('Još nema recepata'), findsOneWidget);
  });
}
