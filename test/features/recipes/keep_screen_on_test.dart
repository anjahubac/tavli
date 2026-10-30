import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder toggle() => find.byTooltip('Ne gasi ekran');

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
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.light_mode_outlined),
          )
          .isSelected,
      isFalse,
    );

    await tester.tap(toggle());
    await tester.pumpAndSettle();

    expect(app.wakeLock.on, isTrue);
    expect(await stored(app), 'true');
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
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.light_mode))
          .isSelected,
      isTrue,
    );
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
