import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart';
import 'package:tavli/app/tab_app_bar.dart';
import 'package:tavli/domain/account.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../helpers/test_app.dart';

void main() {
  TavliNavigation navigation(WidgetTester tester) =>
      tester.widget<TavliNavigation>(find.byType(TavliNavigation));

  List<String> labels(WidgetTester tester) => [
    for (final d in navigation(tester).destinations) d.label,
  ];

  /// Nazivi u bočnoj traci odozgo nadole.
  List<String> sideLabels(WidgetTester tester) {
    final names = [for (final d in navigation(tester).destinations) d.label];
    final found = [
      for (final n in names)
        (
          n,
          tester
              .getTopLeft(
                find.descendant(
                  of: find.byType(TavliNavigation),
                  matching: find.text(n),
                ),
              )
              .dy,
        ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (n, _) in found) n];
  }

  Finder profileAvatar() => find.descendant(
    of: find.byType(TavliAppBar),
    matching: find.bySemanticsLabel('Profil'),
  );

  testTavli('telefon: donji tabovi i prelazak na Ostavu', (tester) async {
    await pumpTavli(tester, size: const Size(390, 844));

    expect(navigation(tester).layout, TavliNavigationLayout.bottom);
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

    expect(find.byType(TavliNavigation), findsOneWidget);
    expect(navigation(tester).layout, TavliNavigationLayout.side);
    // Kao na platnu: na računaru nema gornje trake „Tavli“.
    expect(find.byType(TavliAppBar), findsNothing);
  });

  for (final location in ['/recipes', '/shopping', '/plan']) {
    testTavli('širok ekran $location: bez gornje trake nema praznog pojasa', (
      tester,
    ) async {
      await pumpTavli(tester, size: wide, location: location, settle: false);
      await tester.pump(const Duration(seconds: 1));
      final bars = find.byType(TabAppBar);
      expect(bars, findsWidgets);
      for (final bar in bars.evaluate()) {
        // Scaffold daje traci njenu stvarnu visinu (0), ne preferredSize (64).
        expect(tester.getSize(find.byWidget(bar.widget)).height, 0);
      }
      // Sadržaj ekrana počinje na samom vrhu svog Scaffold-a.
      final scaffold = find
          .ancestor(of: bars.first, matching: find.byType(Scaffold))
          .first;
      final body = tester.widget<Scaffold>(scaffold).body!;
      expect(
        tester.getTopLeft(find.byWidget(body)).dy,
        tester.getTopLeft(scaffold).dy,
      );
    });
  }

  testTavli('pet tabova redom, Početna u sredini', (tester) async {
    await pumpTavli(tester, size: const Size(390, 844), location: '/plan');

    expect(labels(tester), ['Plan', 'Nabavka', 'Početna', 'Recepti', 'Ostava']);
    expect(currentTab(tester), 'Plan');
    // Gore je naziv aplikacije, ne naziv taba.
    expect(
      find.descendant(
        of: find.byType(TavliAppBar),
        matching: find.text('Tavli'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TavliAppBar),
        matching: find.text('Plan'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Nabavka'));
    // Prazna Nabavka ima animaciju u petlji, pa bez pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));
    expect(currentTab(tester), 'Nabavka');
  });

  testTavli('bočni meni: Početna na vrhu, svaka stavka otvara svoj tab', (
    tester,
  ) async {
    await pumpTavli(tester, size: wide, location: '/plan');

    expect(sideLabels(tester), [
      'Početna',
      'Plan',
      'Nabavka',
      'Recepti',
      'Ostava',
    ]);
    expect(
      navigation(tester).selectedIndex,
      tabs.indexWhere((t) => t.label == 'Plan'),
    );
    for (final label in ['Početna', 'Plan', 'Nabavka', 'Recepti', 'Ostava']) {
      await tester.tap(
        find.descendant(
          of: find.byType(TavliNavigation),
          matching: find.text(label),
        ),
      );
      // Početna i Nabavka imaju animacije u petlji, pa bez pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(currentTab(tester), label);
      expect(
        navigation(tester).selectedIndex,
        tabs.indexWhere((t) => t.label == label),
      );
    }
  });

  testTavli('Početna je podrazumevani tab; bez plana nudi „Napravi plan“', (
    tester,
  ) async {
    await pumpTavli(tester, location: homeLocation);

    expect(currentTab(tester), 'Početna');
    expect(
      find.descendant(
        of: find.byType(TavliAppBar),
        matching: find.text('Tavli'),
      ),
      findsOneWidget,
    );
    expect(profileAvatar(), findsOneWidget);
    expect(find.text('Još nema plana obroka'), findsOneWidget);
    expect(find.text('Napravi plan'), findsOneWidget);
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
    expect(navigation(tester).layout, TavliNavigationLayout.side);
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
    expect(profileAvatar(), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TavliAppBar), matching: find.text('AP')),
      findsOneWidget,
    );

    await tester.tap(profileAvatar());
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

        expect(find.byType(TavliAppBar), findsNothing);
        final railProfile = find.descendant(
          of: find.byType(TavliNavigation),
          matching: find.text('Profil'),
        );
        expect(railProfile, findsOneWidget);
        // Avatar postoji samo jednom na ekranu, na dnu bočne trake.
        expect(find.text('AP'), findsOneWidget);
        expect(
          tester.getTopLeft(railProfile).dy,
          greaterThan(
            tester
                .getTopLeft(
                  find.descendant(
                    of: find.byType(TavliNavigation),
                    matching: find.text('Ostava'),
                  ),
                )
                .dy,
          ),
        );

        await tester.tap(railProfile);
        await tester.pumpAndSettle();
        // Širok ekran (platno): Profil ostaje u okviru sa bočnim menijem,
        // istaknut dole, sa naslovom bez povratka.
        expect(find.widgetWithText(TavliPageHeader, 'Profil'), findsOneWidget);
        expect(find.text('Odjavi se'), findsOneWidget);
        expect(find.byType(TavliNavigation), findsOneWidget);
        expect(find.text('Nazad'), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(TavliNavigation),
            matching: find.text('Ostava'),
          ),
        );
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
    expect(
      authRedirect(const NeedsHousehold(_account), Uri.parse('/plan')),
      '/sign-in/household?from=%2Fplan',
    );
    expect(
      authRedirect(
        const NeedsHousehold(_account),
        Uri.parse('/sign-in/household'),
      ),
      isNull,
    );
    expect(
      authRedirect(
        const SignedIn(_account),
        Uri.parse('/sign-in/household?from=%2Fplan'),
      ),
      '/plan',
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
