import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/account/household_setup_screen.dart';
import 'package:tavli/features/home/home_screen.dart';
import 'package:tavli/providers.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  /// Keširan nalog čiji server kaže da korak još nije završen.
  Future<TestApp> pumpSetup(
    WidgetTester tester, {
    Size size = phone,
    FakeBackend? backend,
  }) async {
    final fake = backend ?? FakeBackend();
    final app = await pumpTavli(
      tester,
      size: size,
      location: '/home',
      backend: fake,
      overrides: [syncEngineProvider.overrideWithValue(null)],
      setup: (_) async {
        final uid = fake.server.users.values.single;
        fake.server.profiles[uid]!['household_setup_done'] = false;
      },
    );
    expect(find.byType(HouseholdSetupScreen), findsOneWidget);
    return app;
  }

  testTavli('naziv domaćinstva otvara aplikaciju i čuva se na serveru', (
    tester,
  ) async {
    final app = await pumpSetup(tester);
    expect(find.text('Tvoje domaćinstvo'), findsOneWidget);
    await tester.enterText(
      textField('Naziv domaćinstva'),
      'Domaćinstvo Horvat',
    );
    await tapButton(tester, 'Nastavi');

    expect(find.byType(HomeScreen), findsOneWidget);
    final hid = app.scope.householdId;
    expect(app.backend.server.householdName(hid), 'Domaćinstvo Horvat');
    final row = await app.db.select(app.db.accounts).getSingle();
    expect(row.householdName, 'Domaćinstvo Horvat');
    expect(row.householdReady, isTrue);
  });

  testTavli('prazno polje zadržava „Moje domaćinstvo“', (tester) async {
    final app = await pumpSetup(tester, size: wide);
    await tapButton(tester, 'Nastavi');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.backend.accounts.renameCalls, 1);
    expect(
      app.backend.server.householdName(app.scope.householdId),
      'Moje domaćinstvo',
    );
  });

  testTavli('bez mreže korak ostaje uz poruku', (tester) async {
    final app = await pumpSetup(tester);
    app.backend.server.offline = true;
    await tapButton(tester, 'Nastavi');
    expect(
      find.text('Nema interneta. Za ovaj korak je potrebna veza.'),
      findsOneWidget,
    );
    expect(find.byType(HouseholdSetupScreen), findsOneWidget);
  });

  testTavli('pridruživanje iz koraka: bez pitanja o receptima i brisanju', (
    tester,
  ) async {
    final backend = FakeBackend()..accounts.joinTargetHousehold = 'destination';
    final app = await pumpSetup(tester, backend: backend);
    await tapButton(tester, 'Pridruži se postojećem domaćinstvu');
    await tester.enterText(textField('Kod pozivnice'), '0123-4567-89AB');
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(TavliSheet), matching: button('Nastavi')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pozvan si u'), findsOneWidget);
    expect(find.text('Da, ponesi moje recepte'), findsNothing);
    await tapButton(tester, 'Pridruži se');

    expect(find.text('Trajno brisanje domaćinstva'), findsNothing);
    expect(backend.accounts.lastJoinAck, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.scope.householdId, 'destination');
  });

  testTavli('link pozivnice pre izbora otvara pridruživanje sa kodom', (
    tester,
  ) async {
    final app = await pumpSetup(tester);
    app.links.add(Uri.parse('tavli://household/join#0123456789ab'));
    await tester.pumpAndSettle();

    expect(find.text('Pridruži se domaćinstvu'), findsOneWidget);
    expect(find.text('0123-4567-89AB'), findsOneWidget);
  });

  testTavli('link pozivnice u prijavljenoj aplikaciji otvara pridruživanje', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/home');
    app.links.add(Uri.parse('tavli://household/join#0123456789AB'));
    await tester.pumpAndSettle();

    expect(find.text('Pridruži se domaćinstvu'), findsOneWidget);
    expect(find.text('0123-4567-89AB'), findsOneWidget);
    // Ostali linkovi i dalje idu prijavi (ovde se zanemaruju).
    app.links.add(Uri.parse('tavli://household/other#0123456789AB'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), wide]) {
    testTavli('korak bez prelivanja na ${size.width} px i tekstu 2×', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSetup(tester, size: size);
      await tester.ensureVisible(
        find.text('Pridruži se postojećem domaćinstvu'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
