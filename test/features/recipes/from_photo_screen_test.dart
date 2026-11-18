import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/features/recipes/photo_picker.dart';

import '../../helpers/test_app.dart';

void main() {
  const explanation =
      'Slika recepta iz kuvara, rukom pisan recept ili snimak ekrana.';

  for (final platform in TargetPlatform.values.where(
    (p) => p != TargetPlatform.fuchsia,
  )) {
    for (final size in [const Size(320, 800), wide]) {
      testTavli(
        '${platform.name}, ${size.width}: izbor slike odgovara platformi',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          try {
            final phone =
                platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS;
            // Adapter tvrdi da kamera postoji; računar je ipak ne nudi.
            final app = await pumpTavli(
              tester,
              size: size,
              location: '/recipes/new/photo',
              ai: [aiAnswer(recipeJson('Pita'))],
            );
            expect(find.text(explanation), findsOneWidget);
            expect(find.text('Slikaj'), phone ? findsOneWidget : findsNothing);
            expect(find.text('Izaberi iz galerije'), findsOneWidget);
            expect(find.byType(FilledButton), phone ? findsOne : findsNothing);
            expect(find.byType(OutlinedButton), findsOneWidget);

            // Odustajanje ne šalje AI zahtev, ne čuva ništa i ne prikazuje grešku.
            await tapButton(tester, 'Izaberi iz galerije');
            expect(app.adapter.requests, isEmpty);
            expect(find.text('Slika nije učitana.'), findsNothing);
            expect(find.text(explanation), findsOneWidget);
            expect(await app.titles(), isEmpty);
            expect(app.photos.saved, isEmpty);

            app.picker.next = fakePhoto;
            await tapButton(tester, 'Izaberi iz galerije');
            expect(app.picker.calls, [false, false]);
            expect(find.text('Pita'), findsOneWidget);
            await tapButton(tester, 'Odbaci');
            expect(find.text('Izaberi iz galerije'), findsOneWidget);
            expect(app.photos.saved, isEmpty);
            expect(await app.titles(), isEmpty);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testTavli('${platform.name}: "Sa slike" odmah otvara izbor slike', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final app = await pumpTavli(tester, ai: [aiAnswer(recipeJson('Pita'))]);
        await tester.tap(find.text('Dodaj recept'));
        await tester.pumpAndSettle();
        expect(find.text('Izaberi sliku recepta'), findsOneWidget);
        expect(find.text('Slikaj ili izaberi sliku recepta'), findsNothing);

        // Odustajanje: ostaje lista, bez međuekrana i bez greške.
        await tester.tap(find.text('Sa slike'));
        await tester.pumpAndSettle();
        expect(app.picker.calls, [false]);
        expect(find.text('Recept sa slike'), findsNothing);
        expect(find.text(explanation), findsNothing);
        expect(find.text('Još nema recepata'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(app.adapter.requests, isEmpty);

        // Izabrana slika ide pravo na čitanje i pregled.
        app.picker.next = fakePhoto;
        await tester.tap(find.text('Dodaj recept'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sa slike'));
        await tester.pumpAndSettle();
        expect(app.picker.calls, [false, false]);
        expect(app.adapter.requests, hasLength(1));
        expect(find.text('Pita'), findsOneWidget);
        expect(find.text('Izaberi iz galerije'), findsNothing);
        await tapButton(tester, 'Sačuvaj');
        expect(await app.titles(), ['Pita']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testTavli('macOS: greška izbora iz menija je poruka, bez međuekrana', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final app = await pumpTavli(tester);
      app.picker.failure = Exception('synthetic-picker-failure');
      await tester.tap(find.text('Dodaj recept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sa slike'));
      await tester.pumpAndSettle();
      expect(find.text('Slika nije učitana.'), findsOneWidget);
      expect(find.text('synthetic-picker-failure'), findsNothing);
      expect(find.text('Recept sa slike'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testTavli('${platform.name}: "Sa slike" otvara ekran sa izborom', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final app = await pumpTavli(tester);
        await tester.tap(find.text('Dodaj recept'));
        await tester.pumpAndSettle();
        expect(find.text('Slikaj ili izaberi sliku recepta'), findsOneWidget);
        await tester.tap(find.text('Sa slike'));
        await tester.pumpAndSettle();
        expect(app.picker.calls, isEmpty);
        expect(find.text('Recept sa slike'), findsOneWidget);
        expect(find.text(explanation), findsOneWidget);
        expect(find.text('Slikaj'), findsOneWidget);
        expect(find.text('Izaberi iz galerije'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final (camera, label, message) in [
    (
      true,
      'Slikaj',
      'Tavli nema dozvolu za kameru. Dozvoli pristup u podešavanjima '
          'telefona.',
    ),
    (
      false,
      'Izaberi iz galerije',
      'Tavli nema dozvolu za galeriju. Dozvoli pristup u podešavanjima '
          'telefona.',
    ),
  ]) {
    testTavli('odbijena dozvola ($label): poruka, bez pada', (tester) async {
      final app = await pumpTavli(tester, location: '/recipes/new/photo');
      app.picker.failure = const PhotoAccessDeniedException();

      await tapButton(tester, label);

      expect(app.picker.calls, [camera]);
      expect(find.text(message), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
      expect(app.adapter.requests, isEmpty);
      expect(await app.titles(), isEmpty);
      expect(tester.takeException(), isNull);

      // Posle dozvole izbor ponovo radi.
      app.picker
        ..failure = null
        ..next = fakePhoto;
      await tapButton(tester, 'Izaberi iz galerije');
      expect(find.text(message), findsNothing);
    });
  }

  for (final size in [const Size(320, 800), wide]) {
    for (final mode in ['light', 'dark']) {
      testTavli(
        'macOS ${size.width}, $mode, tekst 2×: tastatura i greška izbora',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final semantics = tester.ensureSemantics();
          try {
            final app = await pumpTavli(
              tester,
              size: size,
              location: '/recipes/new/photo',
              settings: {'theme_mode': mode},
              canUseCamera: false,
            );
            app.picker.failure = Exception('synthetic-picker-failure');
            final picker = button('Izaberi iz galerije');
            expect(
              tester.getSemantics(picker),
              matchesSemantics(
                label: 'Izaberi iz galerije',
                isButton: true,
                hasTapAction: true,
                hasFocusAction: true,
                isFocusable: true,
                hasEnabledState: true,
                isEnabled: true,
              ),
            );
            await tester.ensureVisible(picker);
            Focus.of(tester.element(find.text('Izaberi iz galerije')))
                .requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.text('Slika nije učitana.'), findsOneWidget);
            expect(find.text('synthetic-picker-failure'), findsNothing);
            expect(app.adapter.requests, isEmpty);
            expect(await app.titles(), isEmpty);
            expect(app.photos.saved, isEmpty);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }
  }

  testTavli('slika → pregled → čuvanje čuva i sliku', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Bakina pita'))],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Izaberi iz galerije');

    expect(app.picker.calls, [false]);
    final body = app.adapter.requests.single.data.toString();
    expect(body, contains(AIImage(fakePhoto).toDataUrl()));
    expect(find.text('Bakina pita'), findsOneWidget);
    expect(app.photos.saved, isEmpty);

    await tapButton(tester, 'Sačuvaj');

    expect(await app.titles(), ['Bakina pita']);
    final path = app.photos.saved.keys.single;
    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.imagePath, path);
    expect(row.source, 'photo');
    expect(find.widgetWithText(AppBar, 'Bakina pita'), findsOneWidget);
  });

  testTavli('slikanje kamerom kad postoji kamera', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Slikaj');
    expect(app.picker.calls, [true]);
  });

  testTavli('bez kamere nudi se samo galerija', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      canUseCamera: false,
    );
    expect(find.text('Slikaj'), findsNothing);
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
  });

  testTavli('slika bez recepta: poruka i izbor druge slike', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [
        aiAnswer({'error': 'not_a_recipe'}),
      ],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Izaberi iz galerije');

    expect(find.text('Na slici nije pronađen recept.'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsNothing);
    await tapButton(tester, 'Izaberi drugu sliku');
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
    expect(await app.titles(), isEmpty);
  });

  testTavli('odustajanje od izbora ne menja ništa', (tester) async {
    final app = await pumpTavli(tester, location: '/recipes/new/photo');

    await tapButton(tester, 'Izaberi iz galerije');

    expect(app.adapter.requests, isEmpty);
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
  });

  testTavli('odbačen pregled ne ostavlja sliku', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');

    await tapButton(tester, 'Odbaci');

    expect(app.photos.saved, isEmpty);
    expect(await app.titles(), isEmpty);
  });

  testTavli('spor AI: Prekini zaustavlja čekanje, slika ostaje', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;
    final gate = app.adapter.gate = Completer<void>();

    await tester.tap(button('Izaberi iz galerije'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Čitam recept sa slike…'), findsOneWidget);

    await tester.tap(button('Prekini'));
    await tester.pump();
    expect(find.text('Čitanje je prekinuto.'), findsOneWidget);
    expect(button('Pokušaj ponovo'), findsOneWidget);

    // Kasni odgovor se ne prikazuje.
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pita'), findsNothing);
    expect(find.text('Čitanje je prekinuto.'), findsOneWidget);
  });
}
