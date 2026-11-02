import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli/domain/account.dart';

import '../helpers/test_app.dart';

void main() {
  List<String> labels(WidgetTester tester) => [
    for (final d in tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    ))
      d.label,
  ];

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

  testTavli('četiri taba redom: Plan, Nabavka, Recepti, Ostava', (
    tester,
  ) async {
    await pumpTavli(tester, size: const Size(390, 844), location: '/plan');

    expect(labels(tester), ['Plan', 'Nabavka', 'Recepti', 'Ostava']);
    expect(find.widgetWithText(AppBar, 'Plan'), findsOneWidget);
    await tester.tap(find.text('Nabavka'));
    // Prazna Nabavka ima animaciju u petlji, pa bez pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(AppBar, 'Nabavka'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), wide]) {
    testTavli(
      'avatar otvara Profil, nazad vraća na tab (${size.width.toInt()} px)',
      (tester) async {
        await pumpTavli(tester, size: size, location: '/pantry');

        await tester.tap(find.byTooltip('Profil i podešavanja'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
        expect(find.text('Odjavi se'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Ostava'), findsOneWidget);
      },
    );
  }

  testTavli('direktna adresa /profile: nazad vodi na Plan', (tester) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Plan'), findsOneWidget);
  });

  test('posle prijave bez tražene adrese otvara se Plan', () {
    const signedIn = SignedIn(
      Account(
        userId: 'u1',
        email: 'ana@tavli.test',
        householdId: 'h1',
        householdName: 'Kod Ane',
        role: 'owner',
        displayName: 'Ana',
      ),
    );
    expect(authRedirect(signedIn, Uri.parse('/sign-in')), '/plan');
    expect(
      authRedirect(signedIn, Uri.parse('/sign-in?from=%2Frecipes')),
      '/recipes',
    );
    expect(authRedirect(const SignedOut(), Uri.parse('/plan')), '/sign-in');
  });
}
