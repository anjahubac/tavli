import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli_ui/tavli_ui.dart';

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

    final titles = [
      'Šargarepa čorba',
      'Sarma',
      'Pasulj',
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    final sorted = [...titles]..sort();
    expect(titles, sorted, reason: 'najnoviji recept je prvi');
    expect(find.text('45 min · 4 porcije'), findsNWidgets(3));

    await tester.enterText(find.byType(TavliSearchField), 'sar');
    await tester.pumpAndSettle();
    expect(find.text('Sarma'), findsOneWidget);
    expect(find.text('Šargarepa čorba'), findsOneWidget);
    expect(find.text('Pasulj'), findsNothing);

    await tester.enterText(find.byType(TavliSearchField), 'čorb');
    await tester.pumpAndSettle();
    expect(find.text('Šargarepa čorba'), findsOneWidget);
    expect(find.text('Sarma'), findsNothing);

    await tester.enterText(find.byType(TavliSearchField), 'musaka');
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

    expect(find.byType(TavliSearchField), findsNothing);
    expect(recipeHeading('Sarma'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    // Kategorije redom prodavnice, količina sa zarezom.
    final povrce = tester.getTopLeft(find.text('VOĆE I POVRĆE')).dy;
    final zacini = tester.getTopLeft(find.text('ZAČINI I SOSOVI')).dy;
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

  testTavli(
    'širok ekran: zaglavlje u jednom redu i mreža, recept je ceo ekran',
    (tester) async {
      await pumpTavli(
        tester,
        size: wide,
        recipes: [
          sampleRecipe('a', 'Pasulj', createdAt: DateTime(2026)),
          sampleRecipe('b', 'Sarma', createdAt: DateTime(2026, 2)),
        ],
      );
      // Platno, macOS · Recepti: naslov, pretraga i „Dodaj recept“ u istom
      // redu, ispod mreža kartica sa slikom na vrhu.
      expect(find.byType(TavliCardGrid), findsOneWidget);
      expect(find.byType(TavliFloatingButton), findsNothing);
      final title = tester.getCenter(find.text('Recepti').last).dy;
      expect(tester.getCenter(find.byType(TavliSearchField)).dy, title);
      expect(tester.getCenter(button('Dodaj recept')).dy, title);
      final pasulj = tester.getTopLeft(find.text('Pasulj'));
      final sarma = tester.getTopLeft(find.text('Sarma'));
      expect(pasulj.dy, sarma.dy, reason: 'kartice su u istom redu mreže');

      await tester.tap(find.text('Sarma'));
      await tester.pumpAndSettle();

      // Recept se otvara kao ceo ekran, bez liste pored.
      expect(recipeHeading('Sarma'), findsOneWidget);
      expect(find.text('Pasulj'), findsNothing);
      expect(find.byType(TavliSearchField), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    },
  );

  testTavli('detalj: veliki naslov, AI izmena je u meniju', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    final title = tester.widget<Text>(find.text('Sarma'));
    expect(
      title.style?.fontSize,
      Theme.of(tester.element(find.text('Sarma')))
          .textTheme
          .headlineSmall
          ?.fontSize,
    );
    expect(iconButton('Izmeni sa AI'), findsNothing);
    await tester.tap(iconButton('Još opcija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Izmeni sa AI'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Šta da promenim?'), findsOneWidget);
  });

  testTavli('tablet: recepti u jednoj koloni, kao na telefonu', (tester) async {
    await pumpTavli(
      tester,
      size: const Size(820, 1180),
      recipes: [
        sampleRecipe('a', 'Sarma', createdAt: DateTime.utc(2026, 11, 2)),
        sampleRecipe('b', 'Pasulj'),
      ],
    );
    final first = tester.getTopLeft(find.text('Sarma'));
    final second = tester.getTopLeft(find.text('Pasulj'));
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
    expect(tester.takeException(), isNull);
  });
}
