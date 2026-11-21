import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('telefon: traka sa povratkom, odeljci jedan ispod drugog', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/profile');
    expect(find.widgetWithText(TavliBackAppBar, 'Profil'), findsOneWidget);
    for (final title in ['NALOG', 'PODEŠAVANJA']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('PODEŠAVANJA')).dy,
      greaterThan(tester.getBottomLeft(find.text('Odjavi se')).dy),
    );
    expect(find.text('Sve je sačuvano u nalogu.'), findsOneWidget);
  });

  testTavli('širok ekran: nalog levo, podešavanja desno, bez gornje trake', (
    tester,
  ) async {
    await pumpTavli(tester, size: wide, location: '/profile');
    expect(find.byType(TavliBackAppBar), findsNothing);
    expect(find.widgetWithText(TavliPageHeader, 'Profil'), findsOneWidget);
    final account = tester.getTopLeft(find.text('NALOG'));
    final settings = tester.getTopLeft(find.text('PODEŠAVANJA'));
    expect(settings.dx, greaterThan(account.dx));
    expect(settings.dy, account.dy);
    expect(
      tester.getSize(find.byType(TavliPageHeader)).width,
      lessThanOrEqualTo(TavliWidth.page),
    );
  });

  for (final location in [
    '/profile',
    '/profile/ai-keys',
    '/profile/appearance',
  ]) {
    testTavli('320 px, tekst 2×: $location bez prelivanja', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(tester, size: const Size(320, 700), location: location);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testTavli('Izgled i AI ključevi: povratak vodi na Profil', (tester) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(find.text('AI ključevi'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TavliBackAppBar, 'AI ključevi'), findsOneWidget);
    await tester.tap(iconButton('Nazad'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TavliBackAppBar, 'Profil'), findsOneWidget);
  });
}
