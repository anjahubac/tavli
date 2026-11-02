import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('Profil: inicijali, ime, e-pošta, domaćinstvo, uloga', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/profile');
    expect(find.text('AP'), findsOneWidget);
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(find.text(testEmail), findsOneWidget);
    expect(find.text('Moje domaćinstvo · Vlasnik'), findsOneWidget);
    expect(find.text('Izmeni ime'), findsOneWidget);
    // Zaglavlje je iznad postojećih stavki.
    expect(
      tester.getTopLeft(find.text('Ana Petrović')).dy,
      lessThan(tester.getTopLeft(find.text('AI ključevi')).dy),
    );
  });

  testTavli('jedna reč daje jedno slovo', (tester) async {
    await pumpTavli(tester, location: '/profile', name: 'Ana');
    expect(find.text('A'), findsOneWidget);
  });

  testTavli('"Izmeni ime" menja ime i inicijale svuda', (tester) async {
    final app = await pumpTavli(tester, location: '/profile');
    await tester.tap(find.text('Izmeni ime'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(button('Sačuvaj')).onPressed, isNull);

    await tester.enterText(field, 'Đorđe Šćepanović');
    await tester.pump();
    await tester.tap(button('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Đorđe Šćepanović'), findsOneWidget);
    expect(find.text('ĐŠ'), findsOneWidget);
    final row = (await app.db.select(app.db.accounts).get()).single;
    expect(row.displayName, 'Đorđe Šćepanović');
    expect(
      (await app.db.select(app.db.syncOutbox).get()).single.entity,
      'profile',
    );
  });

  testTavli('"Odustani" ne menja ime', (tester) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(find.text('Izmeni ime'));
    await tester.pumpAndSettle();
    await tester.tap(button('Odustani'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Petrović'), findsOneWidget);
  });

  for (final size in [phone, wide]) {
    testTavli('raspored zaglavlja na ${size.width.toInt()} px', (tester) async {
      await pumpTavli(tester, location: '/profile', size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('AP'), findsOneWidget);
    });
  }
}
