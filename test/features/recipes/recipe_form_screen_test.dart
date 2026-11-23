import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_labels.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => textField(label);

  Future<void> addIngredient(
    WidgetTester tester, {
    required String name,
    String quantity = '',
    String unit = '',
  }) async {
    await tester.ensureVisible(find.text('Dodaj sastojak'));
    await tester.pumpAndSettle();
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

  testTavli('dijalog sastojka: polja se ne dodiruju i ne preklapaju', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/recipes/new/manual');
    await tester.ensureVisible(find.text('Dodaj sastojak'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Dodaj sastojak');
    final dialog = find.byType(AlertDialog);
    Rect rect(Finder f) =>
        tester.getRect(find.descendant(of: dialog, matching: f).first);
    final name = rect(find.widgetWithText(TextField, 'Naziv'));
    final qty = rect(find.widgetWithText(TextField, 'Količina'));
    final unit = rect(find.widgetWithText(TextField, 'Jedinica'));
    final category = rect(find.byType(DropdownButtonFormField<String>));
    final note = rect(find.widgetWithText(TextField, 'Napomena'));

    // Svaka dva susedna reda moraju imati vidljiv razmak, a kolone razmak
    // između sebe.
    expect(qty.top - name.bottom, greaterThanOrEqualTo(8));
    expect(category.top - qty.bottom, greaterThanOrEqualTo(8));
    expect(note.top - category.bottom, greaterThanOrEqualTo(8));
    expect(unit.left - qty.right, greaterThanOrEqualTo(8));
  });

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
    expect(recipeHeading('Kajgana'), findsOneWidget);
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
    expect(recipeHeading('Užina'), findsOneWidget);
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
    expect(recipeHeading('Sarma'), findsOneWidget);
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
  testTavli('izmena količine čuva vezu sastojka', (tester) async {
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

    await tester.tap(iconButton('Izmeni'));
    await tester.pumpAndSettle();
    // Oznake u formi guraju sastojak ispod ekrana.
    await tester.ensureVisible(find.text('3 kom jaja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 kom jaja'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextField, 'Količina'),
      ),
      '4',
    );
    await tester.pump();
    await tester.tap(find.descendant(of: dialog, matching: button('Sačuvaj')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    final row = await app.db.select(app.db.recipes).getSingle();
    final stored = (jsonDecode(row.ingredientsJson) as List).single as Map;
    expect(stored['quantity'], 4);
    expect(stored['foodId'], '00000000-0000-4000-8000-000000000001');
    expect(stored['matchedKey'], 'jaja');
    expect(stored['linkSource'], 'confirmed');
  });

  group('oznake u ručnoj formi (TRELLO-102)', () {
    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testTavli('nov recept čuva izabrane oznake kao korisnikove', (
      tester,
    ) async {
      final app = await pumpTavli(tester, location: '/recipes/new/manual');
      await tester.enterText(field('Naziv'), 'Grčka');
      await tapChip(tester, 'Večera');
      await tapChip(tester, 'Lagan');
      await tapChip(tester, 'Salata');
      await addIngredient(tester, name: 'paradajz');
      await tapButton(tester, 'Sačuvaj');

      final row = await app.db.select(app.db.recipes).getSingle();
      expect(row.mealTypesJson, '["dinner"]');
      expect(row.weight, 'light');
      expect(row.dishKind, 'salad');
      expect(row.labelsSource, 'user');
    });

    for (final size in [
      const Size(320, 640),
      const Size(400, 800),
      const Size(1200, 800),
    ]) {
      testTavli('${size.width} px, tekst 2×, tamna tema, bez animacija: '
          'oznake bez preliva', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pumpTavli(
          tester,
          size: size,
          location: '/recipes/new/manual',
          settings: {'theme_mode': 'dark'},
        );
        await tapChip(tester, 'Doručak');
        await tapChip(tester, 'Kuvano jelo');
        expect(tester.takeException(), isNull);
      });
    }

    testTavli('bez izbora recept ostaje bez oznaka', (tester) async {
      final app = await pumpTavli(tester, location: '/recipes/new/manual');
      await tester.enterText(field('Naziv'), 'Kajgana');
      await addIngredient(tester, name: 'jaja');
      await tapButton(tester, 'Sačuvaj');

      final row = await app.db.select(app.db.recipes).getSingle();
      expect(row.weight, isNull);
      expect(row.labelsSource, isNull);
    });

    testTavli('izmena: promenjene oznake se čuvaju, nedirnute AI ostaju AI', (
      tester,
    ) async {
      final aiLabelled = sampleRecipe('a', 'Sarma').copyWith(
        labels: const RecipeLabels(
          meals: ['lunch'],
          weight: 'hearty',
          dishKind: 'cooked',
          source: 'ai',
        ),
      );
      final app = await pumpTavli(
        tester,
        location: '/recipes/a',
        recipes: [aiLabelled, sampleRecipe('b', 'Pasulj')],
      );

      await tester.tap(iconButton('Izmeni'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Naziv'), 'Posna sarma');
      await tapButton(tester, 'Sačuvaj');
      var row = await (app.db.select(
        app.db.recipes,
      )..where((r) => r.id.equals('a'))).getSingle();
      expect(row.labelsSource, 'ai');
      expect(row.weight, 'hearty');

      final versions = app.db.select(app.db.recipeVersions)
        ..where((v) => v.recipeId.equals('a'));
      expect(await versions.get(), hasLength(1));

      await tester.tap(iconButton('Izmeni'));
      await tester.pumpAndSettle();
      await tapChip(tester, 'Srednji');
      await tapButton(tester, 'Sačuvaj');
      row = await (app.db.select(
        app.db.recipes,
      )..where((r) => r.id.equals('a'))).getSingle();
      expect(row.labelsSource, 'user');
      expect(row.weight, 'medium');
      expect(row.dishKind, 'cooked');
      // Samo oznake: nema nove verzije recepta.
      expect(await versions.get(), hasLength(1));
    });
  });
}
