import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_gateway.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => textField(label);

  Future<TestApp> toSignUp(
    WidgetTester tester, {
    Size size = phone,
    FakeBackend? backend,
  }) async {
    final app = await pumpTavli(
      tester,
      signedIn: false,
      size: size,
      backend: backend,
    );
    await tapButton(tester, 'Registruj se');
    return app;
  }

  Future<TestApp> toCheckEmail(WidgetTester tester, {Size size = phone}) async {
    final app = await toSignUp(tester, size: size);
    await tester.enterText(field('E-pošta'), ' Nova@Mail.com ');
    await tester.pump();
    await tapButton(tester, 'Napravi nalog');
    return app;
  }

  testTavli('"Registruj se": ekran za nov nalog', (tester) async {
    await toSignUp(tester);
    expect(
      find.text(
        'Recepti, nabavka i plan obroka čuvaju se na nalogu. Lozinka nije '
        'potrebna.',
      ),
      findsOneWidget,
    );
    expect(find.text('Poslaćemo ti mejl da potvrdiš adresu.'), findsOneWidget);
    expect(find.text('Već imaš nalog?'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button('Napravi nalog')).onPressed,
      isNull,
    );
  });

  testTavli('nova adresa: "Proveri mejl" i mejl za potvrdu', (tester) async {
    final app = await toCheckEmail(tester);
    expect(find.text('Proveri mejl'), findsOneWidget);
    expect(
      find.text(
        'Poslali smo mejl na nova@mail.com. Dodirni Potvrdi adresu u mejlu '
        'ili upiši kod iz njega.',
      ),
      findsOneWidget,
    );
    expect(app.backend.auth.sentConfirmations, ['nova@mail.com']);
    expect(app.secrets.values, isEmpty);
  });

  testTavli('Windows: samo kod iz mejla', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await toCheckEmail(tester, size: wide);
    expect(
      find.text(
        'Poslali smo mejl na nova@mail.com. Upiši ovde kod iz tog mejla.',
      ),
      findsOneWidget,
    );
  });

  testTavli('kod iz mejla za potvrdu prijavljuje i traži ime', (tester) async {
    final app = await toCheckEmail(tester);
    await tester.enterText(field('Kod iz poruke'), FakeServer.code);
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
    expect(app.backend.auth.unconfirmed, isEmpty);
  });

  testTavli('link iz mejla otvara aplikaciju i prijavljuje', (tester) async {
    final app = await toCheckEmail(tester);
    app.links.add(app.backend.auth.linkFor('nova@mail.com'));
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
    expect(app.secrets.values, isNotEmpty);
  });

  testTavli('iskorišćen link: poruka i "Proveri mejl" ostaje', (tester) async {
    final app = await toCheckEmail(tester);
    app.links.add(Uri.parse('tavli://auth-callback?code=iskoriscen'));
    await tester.pumpAndSettle();
    expect(find.text('Proveri mejl'), findsOneWidget);
    expect(
      find.text(
        'Link je istekao ili je već iskorišćen. Ako si već potvrdio/la '
        'adresu, prijavi se kodom. Ako nisi, pošalji mejl ponovo.',
      ),
      findsOneWidget,
    );
  });

  testTavli('drugi link (nije auth-callback) se zanemaruje', (tester) async {
    final app = await toCheckEmail(tester);
    app.links.add(Uri.parse('tavli://recept/1?code=x'));
    await tester.pumpAndSettle();
    expect(find.text('Proveri mejl'), findsOneWidget);
    expect(find.textContaining('Link je istekao'), findsNothing);
  });

  testTavli('"Pošalji mi kod" i "Pošalji mejl ponovo" posle 30 s', (
    tester,
  ) async {
    final app = await toCheckEmail(tester);
    expect(find.text('Pošalji mejl ponovo (za 30 s)'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button('Pošalji mi kod')).onPressed,
      isNull,
    );

    app.now = app.now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await tapButton(tester, 'Pošalji mi kod');
    expect(app.backend.auth.sentCodes, ['nova@mail.com']);
    expect(find.text('Pošalji mejl ponovo (za 30 s)'), findsOneWidget);

    app.now = app.now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await tapButton(tester, 'Pošalji mejl ponovo');
    expect(app.backend.auth.sentConfirmations, [
      'nova@mail.com',
      'nova@mail.com',
    ]);

    await tester.enterText(field('Kod iz poruke'), FakeServer.code);
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
  });

  testTavli('postojeća adresa: "Prijavi se umesto toga" sa adresom', (
    tester,
  ) async {
    final app = await toSignUp(tester);
    await tester.enterText(field('E-pošta'), testEmail);
    await tester.pump();
    await tester.tap(button('Napravi nalog'));
    await tester.pumpAndSettle();
    expect(find.text('Već postoji nalog sa ovom adresom.'), findsOneWidget);
    expect(app.backend.auth.sentConfirmations, isEmpty);

    await tester.tap(find.text('Prijavi se umesto toga'));
    await tester.pumpAndSettle();
    expect(find.text('Prijava'), findsOneWidget);
    final input = tester.widget<TextField>(field('E-pošta'));
    expect(input.controller!.text, testEmail);
  });

  testTavli('server bez potvrde adrese: odmah ime', (tester) async {
    final backend = FakeBackend()..auth.autoconfirm = true;
    await toSignUp(tester, backend: backend);
    await tester.enterText(field('E-pošta'), 'nova@mail.com');
    await tester.pump();
    await tester.tap(button('Napravi nalog'));
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
  });

  testTavli('greška pri registraciji ostaje na prvom koraku', (tester) async {
    final app = await toSignUp(tester);
    app.backend.auth.failNext = const RateLimited();
    await tester.enterText(field('E-pošta'), 'nova@mail.com');
    await tester.pump();
    await tester.tap(button('Napravi nalog'));
    await tester.pumpAndSettle();
    expect(
      find.text('Previše pokušaja. Sačekaj malo pa pokušaj ponovo.'),
      findsOneWidget,
    );
    expect(field('E-pošta'), findsOneWidget);
  });

  for (final back in ['Promeni e-poštu', 'Nazad']) {
    testTavli('"$back" vraća na registraciju', (tester) async {
      await toCheckEmail(tester);
      await tapButton(tester, back);
      expect(button('Napravi nalog'), findsOneWidget);
      expect(field('Kod iz poruke'), findsNothing);
    });
  }

  for (final size in [phone, wide]) {
    testTavli('"Proveri mejl" na ${size.width.toInt()} px', (tester) async {
      await toCheckEmail(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(field('Kod iz poruke')).right,
        lessThanOrEqualTo(size.width),
      );
    });
  }

  testTavli('"Proveri mejl" uz tekst 2× na 320 px se pomera', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await toCheckEmail(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.text('Proveri mejl'), findsOneWidget);
    await tester.ensureVisible(find.text('Promeni e-poštu'));
    await tester.pumpAndSettle();
    expect(button('Promeni e-poštu'), findsOneWidget);
  });

  // Prozor na Mac-u (845×645 sa naslovnom trakom) i druge veličine između
  // telefona i računara: uz poruku o isteklom linku ništa ne ispada iz
  // ekrana, a dno se skroluje.
  for (final size in const [
    Size(845, 590),
    Size(600, 800),
    Size(719, 560),
    Size(1200, 480),
    Size(844, 390),
  ]) {
    testTavli('"Proveri mejl" sa greškom na ${size.width.toInt()}×'
        '${size.height.toInt()}', (tester) async {
      final app = await toCheckEmail(tester, size: size);
      app.links.add(Uri.parse('tavli://auth-callback?code=iskoriscen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Promeni e-poštu'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(button('Promeni e-poštu')).bottom,
        lessThanOrEqualTo(size.height),
      );
    });
  }

  testTavli('telefon: dno ekrana je dole kad ima mesta', (tester) async {
    const size = Size(430, 1100);
    await toCheckEmail(tester, size: size);
    expect(
      tester.getRect(button('Promeni e-poštu')).bottom,
      greaterThan(size.height - 100),
    );
  });
}
