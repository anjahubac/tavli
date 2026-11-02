import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  Finder nameField() => find.widgetWithText(TextField, 'Ime');
  VoidCallback? next(WidgetTester tester) =>
      tester.widget<FilledButton>(button('Nastavi')).onPressed;

  testTavli('nalog bez imena: korak sa imenom pre aplikacije', (tester) async {
    await pumpTavli(tester, name: null);
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Preskoči'), findsNothing);
  });

  testTavli('"Nastavi" je isključeno za prazno ime ili razmake', (
    tester,
  ) async {
    await pumpTavli(tester, name: null);
    expect(next(tester), isNull);
    await tester.enterText(nameField(), '   ');
    await tester.pump();
    expect(next(tester), isNull);
    await tester.enterText(nameField(), 'Ana');
    await tester.pump();
    expect(next(tester), isNotNull);
  });

  testTavli('ime je najviše 40 znakova', (tester) async {
    await pumpTavli(tester, name: null);
    await tester.enterText(nameField(), 'a' * 45);
    await tester.pump();
    final field = tester.widget<TextField>(nameField());
    expect(field.controller!.text, hasLength(40));
  });

  testTavli('čuvanje imena otvara Recepte i šalje profil', (tester) async {
    final app = await pumpTavli(tester, name: null);
    await tester.enterText(nameField(), '  Ana Petrović ');
    await tester.pump();
    await tester.tap(button('Nastavi'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Recepti'), findsOneWidget);
    final row = (await app.db.select(app.db.accounts).get()).single;
    expect(row.displayName, 'Ana Petrović');
    final e = (await app.db.select(app.db.syncOutbox).get()).single;
    expect(e.entity, 'profile');
  });

  for (final size in [phone, wide]) {
    testTavli('raspored na ${size.width.toInt()} px', (tester) async {
      await pumpTavli(tester, name: null, size: size);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(nameField()).width, lessThanOrEqualTo(420));
    });
  }
}
