import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/settings/animations_gallery_screen.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('galerija prikazuje sve animacije sa opisom gde i kada', (
    tester,
  ) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AnimationsGalleryScreen(),
          ),
        ),
      ),
    );
    expect(animationEntries, hasLength(12));
    for (final e in animationEntries) {
      await tester.scrollUntilVisible(
        find.text(e.title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(e.title), findsOneWidget);
      expect(find.text(e.where), findsOneWidget);
    }
    expect(find.text('Ponovi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testTavli('Ostava i Nabavka imaju animirana prazna stanja', (tester) async {
    await pumpTavli(tester);
    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(find.text('Još nema unetih namirnica'), findsOneWidget);
    expect(
      find.text('Ovde ćeš pratiti namirnice koje imaš kod kuće.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Prazan frižider'), findsOneWidget);

    await tester.tap(find.text('Nabavka'));
    // Sačekaj obe lokalne liste i inicijalizaciju prikaza Nabavke.
    await tester.pumpAndSettle();
    expect(find.text('Nabavka je prazna'), findsOneWidget);
    expect(find.bySemanticsLabel('Prazna korpa za nabavku'), findsOneWidget);
    await tester.tap(find.text('Pogledaj recepte'));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Recepti');
  });
  for (final size in [const Size(320, 900), wide]) {
    testTavli('prazni ekrani sa 2× tekstom na ${size.width} px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(tester, size: size, location: '/pantry');
      expect(find.text('Još nema unetih namirnica'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TavliIcon && w.icon == TavliIcons.shopping,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nabavka je prazna'), findsOneWidget);
      await tester.ensureVisible(find.text('Pogledaj recepte'));
      await tester.tap(find.text('Pogledaj recepte'));
      await tester.pumpAndSettle();
      expect(currentTab(tester), 'Recepti');
      expect(tester.takeException(), isNull);
    });
  }
}
