import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';
import '../planning/plan_calendar_test.dart' show seedPlan;

void main() {
  Recipe musaka({List<String>? steps}) => Recipe(
    id: 'm',
    title: 'Musaka',
    servings: 4,
    ingredients: const [
      Ingredient(name: 'Crni luk', quantity: 2, unit: 'kom'),
      Ingredient(name: 'Mleveno meso', quantity: 500, unit: 'g'),
      Ingredient(name: 'Krompir', quantity: 1.5, unit: 'kg'),
    ],
    steps:
        steps ??
        const ['Ogulite krompir.', 'Propržite crni luk i meso.', 'Pecite.'],
    source: RecipeSource.manual,
    createdAt: DateTime.utc(2026),
  );

  Finder button(String label) => find.widgetWithText(TavliButton, label);

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<TavliButton>(button(label)).onPressed != null;

  testTavli('Kuvaj otvara korake bez navigacije i drži ekran upaljen', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/m',
      recipes: [musaka()],
    );
    await tester.tap(button('Kuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Kuvanje'), findsOneWidget);
    expect(find.text('KORAK 1 OD 3'), findsOneWidget);
    expect(find.text('Ogulite krompir.'), findsOneWidget);
    expect(find.text('Musaka · 4 porcije'), findsOneWidget);
    expect(find.text('Nabavka'), findsNothing, reason: 'bez navigacije');
    expect(app.wakeLock.on, isTrue);
    expect(enabled(tester, 'Prethodni'), isFalse);

    // Sastojci ovog koraka.
    expect(find.text('U OVOM KORAKU'), findsOneWidget);
    expect(find.text('Krompir'), findsOneWidget);
    expect(find.text('1,5 kg'), findsOneWidget);

    await tester.tap(button('Sledeći'));
    await tester.pumpAndSettle();
    expect(find.text('KORAK 2 OD 3'), findsOneWidget);
    expect(find.text('Crni luk'), findsOneWidget);
    expect(find.text('Mleveno meso'), findsOneWidget);
    expect(enabled(tester, 'Prethodni'), isTrue);

    await tester.tap(button('Prethodni'));
    await tester.pumpAndSettle();
    expect(find.text('KORAK 1 OD 3'), findsOneWidget);

    await tester.tap(button('Sledeći'));
    await tester.pumpAndSettle();
    await tester.tap(button('Sledeći'));
    await tester.pumpAndSettle();
    expect(find.text('KORAK 3 OD 3'), findsOneWidget);
    expect(button('Sledeći'), findsNothing);

    // Recept iz biblioteke nije obrok iz plana: kraj je „Gotovo“.
    await tester.tap(button('Gotovo'));
    await tester.pumpAndSettle();
    expect(find.text('Kuvanje'), findsNothing);
    expect(app.wakeLock.on, isFalse);
  });

  testTavli('Prethodni i Sledeći su iste veličine', (tester) async {
    await pumpTavli(tester, location: '/cook/recipe/m', recipes: [musaka()]);
    final a = tester.getSize(button('Prethodni'));
    final b = tester.getSize(button('Sledeći'));
    expect(a, b);
    expect(a.height, greaterThanOrEqualTo(48));
  });

  testTavli('na telefonu sastojci su u listi; kvačice ostaju dok se kuva', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/cook/recipe/m', recipes: [musaka()]);
    expect(find.byType(TavliCheckRow), findsNothing);

    await tester.tap(button('Sastojci'));
    await tester.pumpAndSettle();
    expect(find.byType(TavliCheckRow), findsNWidgets(3));
    await tester.tap(find.widgetWithText(TavliCheckRow, 'Krompir'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TavliCheckRow>(find.widgetWithText(TavliCheckRow, 'Krompir'))
          .checked,
      isTrue,
    );

    // Zatvori list povlačenjem i otvori ponovo.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    await tester.tap(button('Sastojci'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TavliCheckRow>(find.widgetWithText(TavliCheckRow, 'Krompir'))
          .checked,
      isTrue,
    );
  });

  testTavli('na širokom ekranu sastojci su stalno u panelu', (tester) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/cook/recipe/m',
      recipes: [musaka()],
    );
    expect(find.byType(TavliCheckRow), findsNWidgets(3));
    expect(button('Sastojci'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testTavli('telefon 320, tekst ${scale}x: bez prelivanja', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: const Size(320, 640),
        location: '/cook/recipe/m',
        recipes: [musaka()],
      );
      expect(tester.takeException(), isNull);
      expect(button('Sledeći').hitTestable(), findsOneWidget);
    });
  }

  testTavli('recept bez koraka: napomena i sastojci', (tester) async {
    await pumpTavli(
      tester,
      location: '/cook/recipe/m',
      recipes: [musaka(steps: const [])],
    );
    expect(find.text('Koraci pripreme nisu uneti.'), findsOneWidget);
    expect(find.text('Dodaj korake'), findsOneWidget);
    expect(find.text('Krompir'), findsOneWidget);
    expect(button('Prethodni'), findsNothing);
    expect(button('Gotovo'), findsOneWidget);
  });

  testTavli('obrok iz plana: Skuvano jednom, pa Poništi', (tester) async {
    String? planId;
    final app = await pumpTavli(
      tester,
      location: '/plan',
      setup: (db) async {
        planId = await seedPlan(
          db,
          DateRange(CivilDate(2026, 11, 2), CivilDate(2026, 11, 2)),
        );
      },
    );
    final entry = await app.db.select(app.db.mealPlanEntries).getSingle();
    expect(entry.isCooked, isFalse);

    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push<void>('/cook/meal/$planId/${entry.id}'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Koraci pripreme nisu uneti.'), findsOneWidget);
    await tester.tap(button('Skuvano'));
    await tester.pumpAndSettle();

    expect(find.text('Kuvanje'), findsNothing);
    expect(find.text('Obrok je skuvan.'), findsOneWidget);
    var row = await app.db.select(app.db.mealPlanEntries).getSingle();
    expect(row.isCooked, isTrue);
    expect(await app.db.select(app.db.cookedEvents).get(), hasLength(1));

    await tester.tap(find.text('Poništi'));
    await tester.pumpAndSettle();
    row = await app.db.select(app.db.mealPlanEntries).getSingle();
    expect(row.isCooked, isFalse);
    final events = await app.db.select(app.db.cookedEvents).get();
    expect(events, hasLength(1), reason: 'zapis se ne briše, samo poništava');
    expect(events.single.undoneAt, isNotNull);
  });
}
