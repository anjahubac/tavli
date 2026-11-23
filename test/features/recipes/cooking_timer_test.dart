import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/features/recipes/cooking_timer.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

class _FakeAlert implements CookingTimerAlert {
  int played = 0;

  @override
  Future<void> play() async => played++;
}

void main() {
  Recipe pasta() => Recipe(
    id: 'm',
    title: 'Testenina',
    servings: 2,
    ingredients: const [
      Ingredient(name: 'Testenina', quantity: 200, unit: 'g'),
    ],
    steps: const [
      'Kuvaj testeninu 8 minuta.',
      'Procedi i dodaj sos.',
      'Peci 20 minuta.',
    ],
    source: RecipeSource.manual,
    createdAt: DateTime.utc(2026),
  );

  Finder button(String label) => find.widgetWithText(TavliButton, label);

  testTavli('tajmer: pokretanje, traka u drugom koraku, kraj sa zvukom', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 23, 12);
    final alert = _FakeAlert();
    Future<void> advance(Duration d) async {
      now = now.add(d);
      await tester.pump(d);
    }

    await pumpTavli(
      tester,
      location: '/cook/recipe/m',
      recipes: [pasta()],
      overrides: [
        clockProvider.overrideWithValue(() => now),
        cookingTimerAlertProvider.overrideWithValue(alert),
      ],
    );

    expect(button('Pokreni tajmer · 8:00'), findsOneWidget);
    await tester.tap(button('Pokreni tajmer · 8:00'));
    await tester.pump();
    expect(find.bySemanticsLabel('Jaje se kuva'), findsOneWidget);
    expect(find.text('8:00'), findsOneWidget);
    expect(find.text('Preostalo'), findsOneWidget);

    await advance(const Duration(minutes: 1));
    expect(find.text('7:00'), findsOneWidget);

    // Drugi korak bez vremena: tajmer radi u traci, dodir vraća na korak.
    await tester.tap(button('Sledeći'));
    await tester.pump();
    expect(find.text('KORAK 2 OD 3'), findsOneWidget);
    expect(find.textContaining('Tajmer · 7:00 · korak 1'), findsOneWidget);
    expect(button('Pokreni tajmer · 8:00'), findsNothing);
    await tester.tap(find.textContaining('Tajmer · 7:00'));
    await tester.pump();
    expect(find.text('KORAK 1 OD 3'), findsOneWidget);

    // Pauza zaustavlja vreme, „+1 min“ ga produžava.
    await tester.tap(button('Pauziraj'));
    await tester.pump();
    expect(find.text('Pauzirano'), findsOneWidget);
    await advance(const Duration(minutes: 3));
    expect(find.text('7:00'), findsOneWidget);
    await tester.tap(button('+1 min'));
    await tester.pump();
    expect(find.text('8:00'), findsOneWidget);
    await tester.tap(button('Nastavi'));
    await tester.pump();

    // Kraj: zvuk jednom, poruka ostaje i na drugom koraku dok se ne zatvori.
    await advance(const Duration(minutes: 8));
    expect(alert.played, 1);
    expect(find.text('Vreme je isteklo'), findsOneWidget);
    await tester.tap(button('Sledeći'));
    await tester.pump();
    expect(find.textContaining('Vreme je isteklo'), findsOneWidget);
    await tester.tap(button('Zatvori'));
    await tester.pump();
    expect(find.textContaining('Vreme je isteklo'), findsNothing);
    expect(find.textContaining('Tajmer ·'), findsNothing);
    await tester.pumpAndSettle();
  });

  testTavli('tajmer: zaustavi ga uklanja, a novi zamenjuje stari', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 23, 12);
    await pumpTavli(
      tester,
      location: '/cook/recipe/m',
      recipes: [pasta()],
      overrides: [
        clockProvider.overrideWithValue(() => now),
        cookingTimerAlertProvider.overrideWithValue(_FakeAlert()),
      ],
    );
    await tester.tap(button('Pokreni tajmer · 8:00'));
    await tester.pump();
    await tester.tap(button('Zaustavi'));
    await tester.pump();
    expect(find.bySemanticsLabel('Jaje se kuva'), findsNothing);
    expect(button('Pokreni tajmer · 8:00'), findsOneWidget);

    await tester.tap(button('Pokreni tajmer · 8:00'));
    await tester.pump();
    await tester.tap(button('Sledeći'));
    await tester.pump();
    await tester.tap(button('Sledeći'));
    await tester.pump();
    expect(find.text('KORAK 3 OD 3'), findsOneWidget);
    expect(
      find.text('Pokretanje zamenjuje tajmer iz drugog koraka.'),
      findsOneWidget,
    );
    await tester.tap(button('Pokreni tajmer · 20:00'));
    await tester.pump();
    expect(find.text('20:00'), findsOneWidget);
    expect(find.textContaining('Tajmer ·'), findsNothing);
    await tester.tap(button('Zaustavi'));
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(320, 700), wide]) {
    testTavli('tajmer sa 2× tekstom na ${size.width} px bez preliva', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: size,
        location: '/cook/recipe/m',
        recipes: [pasta()],
        overrides: [cookingTimerAlertProvider.overrideWithValue(_FakeAlert())],
      );
      await tester.ensureVisible(button('Pokreni tajmer · 8:00'));
      await tester.tap(button('Pokreni tajmer · 8:00'));
      await tester.pump();
      await tester.tap(button('Sledeći'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining('Tajmer ·'));
      await tester.pump();
      await tester.ensureVisible(button('Zaustavi'));
      await tester.tap(button('Zaustavi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
