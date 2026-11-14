import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/recipes/keep_screen_on.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder toggle() => find.byType(KeepScreenOnButton);
  Finder statusIcon(IconData icon) =>
      find.descendant(of: toggle(), matching: find.byIcon(icon));

  void expectStatus({required bool on}) {
    expect(
      statusIcon(KeepScreenOnButton.onIcon),
      on ? findsOneWidget : findsNothing,
    );
    expect(
      statusIcon(KeepScreenOnButton.offIcon),
      on ? findsNothing : findsOneWidget,
    );
    expect(
      find.byTooltip(
        on ? 'Ne gasi ekran: uključeno' : 'Ne gasi ekran: isključeno',
      ),
      findsOneWidget,
    );
  }

  Future<String?> stored(TestApp app) async {
    final row = await (app.db.select(
      app.db.appSettings,
    )..where((t) => t.key.equals('keep_screen_on'))).getSingleOrNull();
    return row?.value;
  }

  testTavli('podrazumevano isključeno; uključivanje drži ekran upaljen', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    expect(app.wakeLock.on, isFalse);
    expectStatus(on: false);

    await tester.tap(toggle());
    await tester.pumpAndSettle();

    expect(app.wakeLock.on, isTrue);
    expect(await stored(app), 'true');
    expectStatus(on: true);
    expect(
      find.text('Ekran se neće gasiti dok je recept otvoren.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(toggle());
    await tester.pumpAndSettle();

    expect(app.wakeLock.on, isFalse);
    expect(await stored(app), 'false');
    expectStatus(on: false);
    expect(find.text('Ekran se gasi kao i obično.'), findsOneWidget);
  });

  testTavli('izlazak iz recepta pušta ekran da se ugasi', (tester) async {
    final app = await pumpTavli(tester, recipes: [sampleRecipe('a', 'Sarma')]);
    await tester.tap(find.text('Sarma'));
    await tester.pumpAndSettle();
    await tester.tap(toggle());
    await tester.pumpAndSettle();
    expect(app.wakeLock.on, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(app.wakeLock.on, isFalse);
  });

  testTavli('zapamćen izbor važi odmah pri otvaranju recepta', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/b',
      recipes: [sampleRecipe('b', 'Pasulj')],
      settings: {'keep_screen_on': 'true'},
    );

    expect(app.wakeLock.on, isTrue);
    expectStatus(on: true);
  });

  testTavli('smanjeno kretanje: ikonica se menja odmah', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );

    await tester.tap(toggle());
    await tester.pump();
    await tester.pump();

    expectStatus(on: true);
  });

  testTavli('širok ekran: recept pored liste takođe drži ekran', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      size: wide,
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    await tester.tap(find.text('Sarma'));
    await tester.pumpAndSettle();
    await tester.tap(toggle());
    await tester.pumpAndSettle();

    expect(app.wakeLock.on, isTrue);
  });

  testTavli('ako platforma odbije, aplikacija radi dalje', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Sarma')],
    );
    app.wakeLock.fail = true;

    await tester.tap(toggle());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(app.wakeLock.on, isFalse);
    expect(await stored(app), 'true');
  });
}
