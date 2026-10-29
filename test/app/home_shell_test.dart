import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/app.dart';

void main() {
  testWidgets('telefon: donji tabovi i prelazak na Ostavu', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: TavliApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Recepti'), findsOneWidget);

    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Ostava'), findsOneWidget);
  });

  testWidgets('širok ekran (macOS): bočni meni', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: TavliApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
