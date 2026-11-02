import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_gateway.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> enterEmail(WidgetTester tester, String email) async {
    await tester.enterText(field('E-pošta'), email);
    await tester.pump();
  }

  Future<TestApp> toCodeStep(
    WidgetTester tester, {
    String location = '/recipes',
    Size size = phone,
  }) async {
    final app = await pumpTavli(
      tester,
      signedIn: false,
      location: location,
      size: size,
    );
    await enterEmail(tester, 'Ana@Mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    return app;
  }

  testTavli('bez naloga: samo "Prijava", nijedan tab', (tester) async {
    await pumpTavli(tester, signedIn: false);
    expect(find.text('Prijava'), findsOneWidget);
    expect(
      find.text(
        'Prijavi se e-poštom. Poslaćemo ti kod, lozinka nije potrebna.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Recepti'), findsNothing);
  });

  testTavli('neispravna adresa: dugme isključeno, poruka posle izlaska', (
    tester,
  ) async {
    await pumpTavli(tester, signedIn: false);
    final send = tester.widget<FilledButton>(button('Pošalji kod'));
    expect(send.onPressed, isNull);

    await enterEmail(tester, 'ana@mail');
    expect(find.text('Unesi ispravnu adresu e-pošte.'), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('Unesi ispravnu adresu e-pošte.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(button('Pošalji kod')).onPressed,
      isNull,
    );

    await enterEmail(tester, 'ana@mail.com');
    expect(
      tester.widget<FilledButton>(button('Pošalji kod')).onPressed,
      isNotNull,
    );
  });

  testTavli('kod: 6 cifara se proverava samo, nov nalog traži ime', (
    tester,
  ) async {
    final app = await toCodeStep(tester);
    expect(find.text('Poslali smo kod na ana@mail.com.'), findsOneWidget);
    expect(app.backend.auth.sentCodes, ['ana@mail.com']);

    await tester.enterText(field('Kod iz poruke'), FakeServer.code);
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
  });

  testTavli('nalepljen kod "123 456" se prihvata', (tester) async {
    await toCodeStep(tester);
    await tester.enterText(field('Kod iz poruke'), '123 456');
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
  });

  testTavli('pogrešan kod: poruka i prazno polje', (tester) async {
    await toCodeStep(tester);
    await tester.enterText(field('Kod iz poruke'), '000000');
    await tester.pumpAndSettle();
    expect(
      find.text('Kod nije ispravan. Proveri poruku i pokušaj ponovo.'),
      findsOneWidget,
    );
    final input = tester.widget<TextField>(field('Kod iz poruke'));
    expect(input.controller!.text, isEmpty);
  });

  for (final (failure, text) in [
    (const CodeExpired(), 'Kod je istekao. Pošalji novi kod.'),
    (const RateLimited(), 'Previše pokušaja. Sačekaj malo pa pokušaj ponovo.'),
    (const Offline(), 'Nema interneta. Za prijavu je potrebna veza.'),
    (const Unavailable(), 'Prijava trenutno nije dostupna.'),
  ]) {
    testTavli('greška pri proveri koda: $text', (tester) async {
      final app = await toCodeStep(tester);
      app.backend.auth.failNext = failure;
      await tester.enterText(field('Kod iz poruke'), FakeServer.code);
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      expect(find.text('Poslali smo kod na ana@mail.com.'), findsOneWidget);
    });
  }

  testTavli('greška pri slanju koda ostaje na prvom koraku', (tester) async {
    final app = await pumpTavli(tester, signedIn: false);
    app.backend.auth.failNext = const Offline();
    await enterEmail(tester, 'ana@mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nema interneta. Za prijavu je potrebna veza.'),
      findsOneWidget,
    );
    expect(field('E-pošta'), findsOneWidget);
  });

  testTavli('"Pošalji ponovo" posle 30 s', (tester) async {
    final app = await toCodeStep(tester);
    expect(find.text('Pošalji ponovo za 30 s'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(button('Pošalji ponovo za 30 s')).onPressed,
      isNull,
    );

    app.now = app.now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Pošalji ponovo za 18 s'), findsOneWidget);

    app.now = app.now.add(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<OutlinedButton>(button('Pošalji ponovo')).onPressed,
      isNotNull,
    );
    await tester.tap(button('Pošalji ponovo'));
    await tester.pumpAndSettle();
    expect(app.backend.auth.sentCodes, ['ana@mail.com', 'ana@mail.com']);
    expect(find.text('Pošalji ponovo za 30 s'), findsOneWidget);
  });

  testTavli('"Promeni e-poštu" vraća na prvi korak', (tester) async {
    await toCodeStep(tester);
    await tester.tap(button('Promeni e-poštu'));
    await tester.pumpAndSettle();
    expect(field('E-pošta'), findsOneWidget);
    expect(field('Kod iz poruke'), findsNothing);
  });

  testTavli('duboki link /plan: posle prijave otvara Plan', (tester) async {
    final backend = FakeBackend();
    final uid = backend.server.userFor('ana@mail.com');
    backend.server.profiles[uid]!['display_name'] = 'Ana';
    final app = await pumpTavli(
      tester,
      signedIn: false,
      location: '/plan',
      backend: backend,
    );
    expect(find.text('Prijava'), findsOneWidget);
    await enterEmail(tester, 'ana@mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Kod iz poruke'), FakeServer.code);
    await tester.pumpAndSettle();
    expect(currentTab(tester), 'Plan');
    expect(app.secrets.values, isNotEmpty);
  });

  for (final size in [phone, wide]) {
    testTavli('raspored na ${size.width.toInt()} px', (tester) async {
      await toCodeStep(tester, size: size);
      expect(tester.takeException(), isNull);
      final card = tester.getSize(find.byType(ConstrainedBox).first);
      expect(card.width, lessThanOrEqualTo(size.width));
    });
  }
}
