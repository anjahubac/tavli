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
    expect(find.text('4 porcije · 45 min'), findsNWidgets(3));

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

  testTavli('širok ekran: mreža, pa lista i recept jedno pored drugog', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      size: wide,
      recipes: [
        sampleRecipe('a', 'Pasulj', createdAt: DateTime(2026)),
        sampleRecipe('b', 'Sarma', createdAt: DateTime(2026, 2)),
      ],
    );
    // Bez izabranog recepta: mreža kartica sa slikom na vrhu.
    expect(find.byType(TavliCardGrid), findsOneWidget);
    expect(find.byType(TavliFloatingButton), findsNothing);
    expect(button('Dodaj recept'), findsOneWidget);

    await tester.tap(find.text('Sarma'));
    await tester.pumpAndSettle();

    expect(find.byType(TavliSearchField), findsOneWidget);
    expect(recipeHeading('Sarma'), findsOneWidget);
    expect(find.text('Pasulj'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    final card = tester.widget<TavliCard>(
      find.ancestor(of: find.text('Sarma'), matching: find.byType(TavliCard)),
    );
    expect(card.selected, isTrue);
  });

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

  testTavli('tablet: recepti u dve kolone', (tester) async {
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
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(tester.takeException(), isNull);
  });
}
