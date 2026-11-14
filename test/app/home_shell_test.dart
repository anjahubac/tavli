import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
    expect(currentTab(tester), 'Recepti');

    await tester.tap(find.text('Ostava'));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Ostava');
  });

  testTavli('320 px, tekst 2×: naziv aktivnog taba ostaje u jednom redu', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(tester, size: const Size(320, 900), location: '/shopping');
    final label = tester.renderObject<RenderParagraph>(
      find.text('Nabavka').last,
    );
    final boxes = label.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
    expect(boxes, hasLength(1));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.menu_book_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Recepti');
    expect(tester.takeException(), isNull);
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
    expect(currentTab(tester), 'Plan');
    // Gore je naziv aplikacije, ne naziv taba.
    expect(find.widgetWithText(AppBar, 'Tavli'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Plan'), findsNothing);
    await tester.tap(find.text('Nabavka'));
    // Prazna Nabavka ima animaciju u petlji, pa bez pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));
    expect(currentTab(tester), 'Nabavka');
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
        expect(currentTab(tester), 'Ostava');
      },
    );
  }

  testTavli('direktna adresa /profile: nazad vodi na Plan', (tester) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Plan');
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
