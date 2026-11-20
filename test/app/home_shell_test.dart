import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli/domain/account.dart';
import 'package:tavli/features/account/account_header.dart';

import 'package:tavli_ui/tavli_ui.dart';

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

  testTavli('tekst 2×: prazna Ostava ima manju sliku, naslov je vidljiv', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(tester, size: const Size(320, 640), location: '/pantry');
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getSize(find.byType(FittedBox)).height,
      lessThanOrEqualTo(88),
    );
    final title = tester.getRect(find.text('Još nema unetih namirnica'));
    expect(title.top, lessThan(640 / 2));
    expect(tester.takeException(), isNull);
  });

  testTavli('širok ekran (macOS): bočni meni', (tester) async {
    await pumpTavli(tester, size: wide);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testTavli('pet tabova redom, Početna u sredini', (tester) async {
    await pumpTavli(tester, size: const Size(390, 844), location: '/plan');

    expect(labels(tester), ['Plan', 'Nabavka', 'Početna', 'Recepti', 'Ostava']);
    expect(currentTab(tester), 'Plan');
    // Gore je naziv aplikacije, ne naziv taba.
    expect(find.widgetWithText(AppBar, 'Tavli'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Plan'), findsNothing);
    await tester.tap(find.text('Nabavka'));
    // Prazna Nabavka ima animaciju u petlji, pa bez pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));
    expect(currentTab(tester), 'Nabavka');
  });

  testTavli('bočni meni: Početna na vrhu, svaka stavka otvara svoj tab', (
    tester,
  ) async {
    await pumpTavli(tester, size: wide, location: '/plan');

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(
      [for (final d in rail.destinations) (d.label as Text).data],
      ['Početna', 'Plan', 'Nabavka', 'Recepti', 'Ostava'],
    );
    expect(rail.selectedIndex, 1);
    for (final (index, label) in [
      'Početna',
      'Plan',
      'Nabavka',
      'Recepti',
      'Ostava',
    ].indexed) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(label),
        ),
      );
      // Početna i Nabavka imaju animacije u petlji, pa bez pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(currentTab(tester), label);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        index,
      );
    }
  });

  testTavli('Početna je podrazumevani tab i za sada je prazna', (tester) async {
    await pumpTavli(tester, location: homeLocation, settle: false);
    // Lonac na Početnoj krčka u petlji, pa bez pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));

    expect(currentTab(tester), 'Početna');
    expect(find.widgetWithText(AppBar, 'Tavli'), findsOneWidget);
    expect(find.byTooltip('Profil i podešavanja'), findsOneWidget);
    expect(find.text('Ovde će biti današnji obroci'), findsOneWidget);
    expect(
      find.text('Uskoro: šta se danas kuva i šta treba da uradiš.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testTavli('320 px, tekst 2×: svih pet naziva je čitljivo i dostupno', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(
        tester,
        size: const Size(320, 640),
        location: homeLocation,
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      final home = find.text('Početna').last;
      expect(tester.getCenter(home).dx, closeTo(160, 1));
      for (final tab in tabs) {
        final label = find.text(tab.label).last;
        expect(label, findsOneWidget);
        final text = tester.renderObject<RenderParagraph>(label);
        expect(text.textScaler.scale(12), 24);
        expect(text.didExceedMaxLines, isFalse);
        final target = find.bySemanticsLabel(tab.label).last;
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        await tester.tap(target);
        await tester.pump(const Duration(seconds: 1));
        expect(currentTab(tester), tab.label);
      }
    } finally {
      semantics.dispose();
    }
  });

  testTavli('kompaktni tab se otvara tastaturom pri velikom tekstu', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(tester, size: const Size(320, 640), location: '/pantry');

    // Fokus može da dođe do taba običnim kretanjem tastaturom.
    final label = find.text('Recepti').last;
    final focus = Focus.of(tester.element(label));
    final traversed = <String?>[];
    for (var step = 0; step < 12 && !focus.hasPrimaryFocus; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      traversed.add(FocusManager.instance.primaryFocus?.debugLabel);
    }
    expect(focus.hasPrimaryFocus, isTrue, reason: 'Fokus: $traversed');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Recepti');

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    tester.view.physicalSize = const Size(720, 360);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(currentTab(tester), 'Recepti');
    final primary = FocusManager.instance.primaryFocus!;
    expect(
      [primary, ...primary.ancestors].map((node) => node.debugLabel),
      contains('Tab content'),
    );
    expect(tester.takeException(), isNull);
  });

  testTavli('telefon: avatar gore desno otvara Profil, nazad vraća na tab', (
    tester,
  ) async {
    await pumpTavli(tester, size: const Size(390, 844), location: '/pantry');
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Profil i podešavanja'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Profil i podešavanja'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TavliBackAppBar, 'Profil'), findsOneWidget);
    expect(find.text('Odjavi se'), findsOneWidget);

    await tester.tap(iconButton('Nazad'));
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Ostava');
  });

  for (final width in [800.0, 1200.0]) {
    testTavli(
      'širok ekran (${width.toInt()} px): Profil je na dnu bočnog menija, '
      'avatar se ne ponavlja gore',
      (tester) async {
        await pumpTavli(tester, size: Size(width, 800), location: '/pantry');

        expect(find.byTooltip('Profil i podešavanja'), findsNothing);
        final railProfile = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byType(ProfileRailItem),
        );
        expect(railProfile, findsOneWidget);
        expect(
          find.descendant(of: railProfile, matching: find.text('Profil')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: railProfile, matching: find.text('AP')),
          findsOneWidget,
        );
        // Avatar postoji samo jednom na ekranu.
        expect(find.byType(InitialsAvatar), findsOneWidget);

        await tester.tap(railProfile);
        await tester.pumpAndSettle();
        // Širok ekran: naslov i povratak su na vrhu sadržaja.
        expect(find.widgetWithText(TavliPageHeader, 'Profil'), findsOneWidget);
        expect(find.text('Odjavi se'), findsOneWidget);

        await tester.tap(find.text('Nazad'));
        await tester.pumpAndSettle();
        expect(currentTab(tester), 'Ostava');
      },
    );
  }

  testTavli('direktna adresa /profile: nazad vodi na Početnu', (tester) async {
    await pumpTavli(tester, location: '/profile');
    await tester.tap(iconButton('Nazad'));
    // Lonac na Početnoj krčka u petlji, pa bez pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(currentTab(tester), 'Početna');
  });

  test('posle prijave bez tražene adrese otvara se Početna', () {
    const signedIn = SignedIn(_account);
    expect(authRedirect(signedIn, Uri.parse('/sign-in')), '/home');
    expect(authRedirect(signedIn, Uri.parse('/sign-in/name')), '/home');
    expect(
      authRedirect(signedIn, Uri.parse('/sign-in?from=%2Frecipes')),
      '/recipes',
    );
    expect(authRedirect(signedIn, Uri.parse('/sign-in?from=%2Fplan')), '/plan');
    expect(authRedirect(signedIn, Uri.parse('/home')), isNull);
  });

  test('odjavljen: Početna se ne pamti, druge adrese se pamte', () {
    expect(authRedirect(const SignedOut(), Uri.parse('/home')), '/sign-in');
    expect(
      authRedirect(const SignedOut(), Uri.parse('/plan')),
      '/sign-in?from=%2Fplan',
    );
    expect(
      authRedirect(const SignedOut(), Uri.parse('/recipes/r1')),
      '/sign-in?from=%2Frecipes%2Fr1',
    );
    expect(
      authRedirect(
        const NeedsName(_account),
        Uri.parse('/sign-in?from=%2Fplan'),
      ),
      '/sign-in/name?from=%2Fplan',
    );
  });
}

const _account = Account(
  userId: 'u1',
  email: 'ana@tavli.test',
  householdId: 'h1',
  householdName: 'Kod Ane',
  role: 'owner',
  displayName: 'Ana',
);
