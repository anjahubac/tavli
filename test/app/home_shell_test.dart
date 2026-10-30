import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testTavli('telefon: donji tabovi i prelazak na Ostavu', (tester) async {
    await pumpTavli(tester, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Recepti'), findsOneWidget);

    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Ostava'), findsOneWidget);
  });

  testTavli('širok ekran (macOS): bočni meni', (tester) async {
    await pumpTavli(tester, size: wide);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
