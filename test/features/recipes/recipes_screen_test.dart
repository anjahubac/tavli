import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/recipe.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('prazna lista pokazuje poruku i dugme za dodavanje', (
    tester,
  ) async {
    await pumpTavli(tester);

    expect(find.text('Još nema recepata'), findsOneWidget);
    expect(
      find.text('Dodaj prvi recept sa slike, po nazivu jela ili ručno.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dodaj recept'));
    await tester.pumpAndSettle();
    expect(find.text('Sa slike'), findsOneWidget);
    expect(find.text('Slikaj ili izaberi sliku recepta'), findsOneWidget);
    expect(find.text('Po nazivu jela'), findsOneWidget);
    expect(find.text('Ručno'), findsOneWidget);
  });

  testTavli('najnoviji prvi i pretraga bez kvačica', (tester) async {
    await pumpTavli(
      tester,
      recipes: [
        sampleRecipe('a', 'Pasulj', createdAt: DateTime(2026)),
        sampleRecipe('b', 'Šargarepa čorba', createdAt: DateTime(2026, 3)),
        sampleRecipe('c', 'Sarma', createdAt: DateTime(2026, 2)),
      ],
    );

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(titles, ['Šargarepa čorba', 'Sarma', 'Pasulj']);
    expect(find.text('4 porcije · 45 min'), findsNWidgets(3));

    await tester.enterText(find.byType(SearchBar), 'sar');
    await tester.pumpAndSettle();
    expect(find.text('Sarma'), findsOneWidget);
    expect(find.text('Šargarepa čorba'), findsOneWidget);
    expect(find.text('Pasulj'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'čorb');
    await tester.pumpAndSettle();
    expect(find.text('Šargarepa čorba'), findsOneWidget);
    expect(find.text('Sarma'), findsNothing);

    await tester.enterText(find.byType(SearchBar), 'musaka');
    await tester.pumpAndSettle();
    expect(find.text('Nema recepata za „musaka“.'), findsOneWidget);
  });

  testTavli('telefon: recept se otvara preko celog ekrana', (tester) async {
    await pumpTavli(
      tester,
      recipes: [sampleRecipe('a', 'Sarma').copyWith(answeredBy: 'Gemini Pro')],
    );

    await tester.tap(find.text('Sarma'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsNothing);
    expect(find.widgetWithText(AppBar, 'Sarma'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    // Kategorije redom prodavnice, količina sa zarezom.
    final povrce = tester.getTopLeft(find.text('voće i povrće')).dy;
    final zacini = tester.getTopLeft(find.text('začini i sosovi')).dy;
    expect(povrce, lessThan(zacini));
    expect(find.text('• 0,5 kg kupus'), findsOneWidget);
    expect(find.text('Napravio: Gemini Pro'), findsOneWidget);
    expect(find.text('Priprema'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Umotati.'), findsOneWidget);
  });

  testTavli('recept bez koraka i ručno unet', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [
        Recipe(
          id: 'a',
          title: 'Salata',
          servings: 1,
          ingredients: const [Ingredient(name: 'paradajz')],
          source: RecipeSource.manual,
          createdAt: DateTime(2026),
        ),
      ],
    );

    expect(find.text('Priprema'), findsOneWidget);
    expect(find.text('Koraci pripreme nisu uneti.'), findsOneWidget);
    expect(find.text('• paradajz'), findsOneWidget);
    expect(find.text('Ručno unet'), findsOneWidget);
    expect(find.text('1 porcija'), findsOneWidget);
  });

  testTavli('oznake: neoznačen recept, izmena i čuvanje', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );

    expect(find.text('Oznake'), findsOneWidget);
    expect(
      find.textContaining('Nije označeno', findRichText: true),
      findsNWidgets(3),
    );

    await tester.tap(find.text('Izmeni oznake'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Ručak'));
    await tester.tap(find.widgetWithText(FilterChip, 'Večera'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Jak'));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Kuvano jelo'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kuvano jelo'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Sačuvaj');

    expect(find.text('Oznake su sačuvane.'), findsOneWidget);
    expect(
      find.text('Obrok: Ručak, Večera', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Težina: Jak', findRichText: true), findsOneWidget);
    expect(
      find.text('Vrsta jela: Kuvano jelo', findRichText: true),
      findsOneWidget,
    );
    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.labelsSource, 'user');
    expect(await app.db.select(app.db.recipeVersions).get(), isEmpty);
  });

  testTavli('oznake: Otkaži ne menja ništa', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    await tester.tap(find.text('Izmeni oznake'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Ručak'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Otkaži');

    expect(
      find.textContaining('Nije označeno', findRichText: true),
      findsNWidgets(3),
    );
    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.labelsSource, isNull);
  });

  for (final size in [const Size(320, 700), wide]) {
    testTavli('${size.width} px, tekst 2×: izmena oznaka bez preliva', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: size,
        location: '/recipes/a',
        recipes: [sampleRecipe('a', 'Sarma')],
      );
      await tester.ensureVisible(find.text('Izmeni oznake'));
      await tester.tap(find.text('Izmeni oznake'));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(12));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (label, size) in [('telefon', phone), ('širok ekran', wide)]) {
    testTavli('recept bez koraka: $label, tekst 2× i smanjeno kretanje', (
      tester,
    ) async {
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
        location: '/recipes/a',
        recipes: [sampleRecipe('a', 'Sarma').copyWith(steps: [])],
      );

      expect(find.text('Sastojci'), findsOneWidget);
      expect(find.text('Priprema'), findsOneWidget);
      expect(find.text('Koraci pripreme nisu uneti.'), findsOneWidget);
    });
  }

  testTavli('širok ekran: lista i recept jedno pored drugog', (tester) async {
    await pumpTavli(
      tester,
      size: wide,
      recipes: [
        sampleRecipe('a', 'Pasulj', createdAt: DateTime(2026)),
        sampleRecipe('b', 'Sarma', createdAt: DateTime(2026, 2)),
      ],
    );
    expect(find.text('Izaberi recept'), findsOneWidget);

    await tester.tap(find.text('Sarma'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Sarma'), findsOneWidget);
    expect(find.text('Pasulj'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Sarma'),
    );
    expect(tile.selected, isTrue);
  });
}
