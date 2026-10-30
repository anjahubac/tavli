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
