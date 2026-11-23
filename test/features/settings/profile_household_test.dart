import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

/// Marko je član domaćinstva test naloga (Ana, vlasnik).
FakeBackend withMember() {
  final backend = FakeBackend();
  final ana = backend.server.userFor(testEmail);
  final marko = backend.server.userFor('marko@tavli.test');
  backend.server.profiles[ana]!['display_name'] = 'Ana Petrović';
  backend.server.profiles[marko]!['display_name'] = 'Marko Horvat';
  backend.server.households[marko] = backend.server.households[ana]!;
  backend.server.roles[marko] = 'member';
  return backend;
}

Future<void> openRow(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testTavli('kartica domaćinstva se otvara na spisak članova', (tester) async {
    await pumpTavli(tester, location: '/profile', backend: withMember());
    expect(find.text('2 člana'), findsOneWidget);
    expect(find.text('Marko Horvat'), findsNothing);

    await openRow(tester, 'Moje domaćinstvo');
    expect(find.text('Marko Horvat'), findsOneWidget);
    expect(find.text('Vlasnik · ti'), findsOneWidget);
    expect(find.text('Član'), findsOneWidget);

    await openRow(tester, 'Moje domaćinstvo');
    expect(find.text('Marko Horvat'), findsNothing);
  });

  testTavli('bez mreže kartica javlja grešku, a sa vezom učita članove', (
    tester,
  ) async {
    final backend = withMember();
    final app = await pumpTavli(
      tester,
      location: '/profile',
      backend: backend,
      setup: (_) async => backend.server.offline = true,
    );
    await openRow(tester, 'Moje domaćinstvo');
    expect(find.text('Članovi trenutno nisu dostupni.'), findsOneWidget);
    // Posle potvrde članstva (nova veza) spisak se sam učitava.
    app.backend.server.offline = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Marko Horvat'), findsOneWidget);
  });

  testTavli('vlasnik menja naziv i uklanja člana uz potvrdu', (tester) async {
    final backend = withMember();
    final app = await pumpTavli(tester, location: '/profile', backend: backend);
    await openRow(tester, 'Izmeni domaćinstvo');
    expect(find.byType(TavliDialog<String?>), findsOneWidget);
    // Vlasnik nema dugme za uklanjanje sebe.
    expect(iconButton('Ukloni člana Ana Petrović'), findsNothing);

    await tester.tap(iconButton('Ukloni člana Marko Horvat'));
    await tester.pumpAndSettle();
    expect(find.text('Ukloni člana?'), findsOneWidget);
    await tapButton(tester, 'Ukloni');
    expect(find.text('Marko Horvat'), findsNothing);
    final marko = backend.server.users['marko@tavli.test']!;
    expect(backend.server.households[marko], isNot(app.scope.householdId));

    await tester.enterText(textField('Naziv domaćinstva'), 'Kuća Petrović');
    await tester.pump();
    await tapButton(tester, 'Sačuvaj');
    expect(find.text('Kuća Petrović'), findsOneWidget);
    expect(
      backend.server.householdName(app.scope.householdId),
      'Kuća Petrović',
    );
  });

  testTavli('član ne vidi izmenu, ali deli pozivnicu i može da pređe', (
    tester,
  ) async {
    final backend = FakeBackend();
    final ana = backend.server.userFor(testEmail);
    backend.server.roles[ana] = 'member';
    await pumpTavli(tester, location: '/profile', backend: backend);
    expect(find.text('Izmeni domaćinstvo'), findsNothing);
    expect(find.text('Pridruži se novom domaćinstvu'), findsOneWidget);
    await openRow(tester, 'Podeli domaćinstvo');
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);
  });

  for (final size in [phone, wide]) {
    testTavli('Podeli domaćinstvo: QR, kod i kopiranje (${size.width} px)', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpTavli(tester, size: size, location: '/profile');
      await openRow(tester, 'Podeli domaćinstvo');
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);
      expect(
        find.text(size == phone ? 'Pošalji pozivnicu' : 'Kopiraj link'),
        findsOneWidget,
      );
      await tapButton(tester, 'Kopiraj kod');
      expect(find.text('Kod je kopiran.'), findsOneWidget);
      expect(copied, 'K7M4-P9RX-5TQ8');
    });
  }

  testTavli('Podeli domaćinstvo bez mreže: greška i ponovni pokušaj', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/profile');
    app.backend.server.offline = true;
    await openRow(tester, 'Podeli domaćinstvo');
    expect(
      find.text('Nema interneta. Pozivnica se prikazuje uz vezu.'),
      findsOneWidget,
    );
    app.backend.server.offline = false;
    await tapButton(tester, 'Pokušaj ponovo');
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);
  });

  testTavli('vlasnik pravi novu pozivnicu posle potvrde', (tester) async {
    final app = await pumpTavli(tester, location: '/profile');
    final accounts = app.backend.accounts;
    await openRow(tester, 'Podeli domaćinstvo');
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);

    await openRow(tester, 'Napravi novu pozivnicu');
    expect(find.text('Napraviti novu pozivnicu?'), findsOneWidget);
    await tester.tap(find.text('Otkaži'));
    await tester.pumpAndSettle();
    expect(accounts.regenerateCalls, 0);
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);

    await openRow(tester, 'Napravi novu pozivnicu');
    await tester.tap(find.text('Napravi novu'));
    await tester.pumpAndSettle();
    expect(accounts.regenerateCalls, 1);
    expect(find.text('Nova pozivnica je spremna.'), findsOneWidget);
    expect(find.text('W2N6-H3JD-8VQC'), findsOneWidget);
    expect(find.text('K7M4-P9RX-5TQ8'), findsNothing);
  });

  testTavli('nova pozivnica bez mreže ostavlja stari kod', (tester) async {
    final app = await pumpTavli(tester, location: '/profile');
    await openRow(tester, 'Podeli domaćinstvo');
    app.backend.server.offline = true;
    await openRow(tester, 'Napravi novu pozivnicu');
    await tester.tap(find.text('Napravi novu'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nema interneta. Nova pozivnica se pravi uz vezu.'),
      findsOneWidget,
    );
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);
  });

  testTavli('član ne vidi dugme za novu pozivnicu', (tester) async {
    final backend = FakeBackend();
    backend.server.roles[backend.server.userFor(testEmail)] = 'member';
    await pumpTavli(tester, location: '/profile', backend: backend);
    await openRow(tester, 'Podeli domaćinstvo');
    expect(find.text('K7M4-P9RX-5TQ8'), findsOneWidget);
    expect(find.text('Napravi novu pozivnicu'), findsNothing);
  });

  testTavli('profil sa domaćinstvom bez prelivanja na 320 px i tekstu 2×', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(
      tester,
      size: const Size(320, 700),
      location: '/profile',
      backend: withMember(),
    );
    await openRow(tester, 'Moje domaćinstvo');
    await openRow(tester, 'Podeli domaćinstvo');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
