import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => find.widgetWithText(TextField, label);

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

  testTavli('izmena čuva prethodnu verziju kao ručnu izmenu', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );

    await tester.tap(find.byTooltip('Izmeni'));
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
    await tester.tap(find.byTooltip('Još opcija'));
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
    await tester.tap(find.byTooltip('Izmeni'));
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

    await tester.tap(find.byTooltip('Još opcija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši recept'));
    await tester.pumpAndSettle();
    expect(find.text('Obrisati „Sarma“?'), findsOneWidget);

    await tester.tap(find.text('Otkaži'));
    await tester.pumpAndSettle();
    expect(await app.titles(), ['Sarma']);

    await tester.tap(find.byTooltip('Još opcija'));
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
