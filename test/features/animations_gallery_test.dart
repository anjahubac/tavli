import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/app_theme.dart';
import 'package:tavli/domain/theme_choice.dart';
import 'package:tavli/features/settings/animations_gallery_screen.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('galerija prikazuje svih devet animacija po imenu', (
    tester,
  ) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliTheme.bosiljak, Brightness.light),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AnimationsGalleryScreen(),
          ),
        ),
      ),
    );
    expect(animationNames, hasLength(11)); // uvod ×3 + 8
    for (final name in animationNames) {
      await tester.scrollUntilVisible(
        find.text(name),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sastojci: štikliran = imam (ne ide u kupovinu), '
      'neštiklirani idu dugmetom', (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliTheme.bosiljak, Brightness.light),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AnimationsGalleryScreen(),
          ),
        ),
      ),
    );
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Označi sastojke koje već imaš'),
      300,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.text('Kupovina'),
      200,
      scrollable: scrollable,
    );
    // Mleveno meso je već štiklirano: "imam", dva sastojka nedostaju.
    expect(find.text('imam'), findsOneWidget);
    expect(find.text('Dodaj u kupovinu (2)'), findsOneWidget);

    // Štikliranje (imam) ne menja Kupovinu.
    await tester.ensureVisible(find.text('Krompir'));
    await tester.pump();
    await tester.tap(find.text('Krompir'));
    await tester.pump();
    expect(find.text('imam'), findsNWidgets(2));
    expect(find.text('Dodaj u kupovinu (1)'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Dugme šalje samo neštiklirane: bedž pokazuje 1.
    await tester.ensureVisible(find.text('Dodaj u kupovinu (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj u kupovinu (1)'));
    await tester.pump();
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testTavli('Ostava i Kupovina imaju animirana prazna stanja', (tester) async {
    await pumpTavli(tester);
    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(find.text('Ostava je prazna'), findsOneWidget);
    expect(find.text('Vreme je za nabavku'), findsOneWidget);
    expect(find.bySemanticsLabel('Prazan frižider'), findsOneWidget);

    await tester.tap(find.text('Kupovina'));
    // Motiv teme se vrti u petlji, pa bez pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Lista je prazna'), findsOneWidget);
    expect(find.bySemanticsLabel('Grančica bosiljka'), findsOneWidget);
  });
}
