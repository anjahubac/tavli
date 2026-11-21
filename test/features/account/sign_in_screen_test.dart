import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/features/account/auth_brand.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  Finder field(String label) => textField(label);

  Future<void> enterEmail(WidgetTester tester, String email) async {
    await tester.enterText(field('E-pošta'), email);
    await tester.pump();
  }

  /// Odjavljen, a nalog ana@mail.com postoji na serveru (bez imena).
  FakeBackend withAna() => FakeBackend()..server.userFor('ana@mail.com');

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
      backend: withAna(),
    );
    await enterEmail(tester, 'Ana@Mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('znak zadržava prostor dok se slika učitava', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AuthBrand())),
    );

    final image = find.byType(RawImage);
    expect(tester.widget<RawImage>(image).image, isNull);
    final size = tester.getSize(image);
    expect(size.width, greaterThan(0));
    expect(size.height, size.width);
  });

  testTavli('bez naloga: samo "Prijava", nijedan tab', (tester) async {
    await pumpTavli(tester, signedIn: false);
    expect(find.text('Prijava'), findsOneWidget);
    expect(find.bySemanticsLabel('Tavli'), findsOneWidget);
    expect(
      find.text(
        'Upiši e-poštu naloga i poslaćemo ti kod za prijavu. Lozinka nije '
        'potrebna.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nemaš nalog?'), findsOneWidget);
    expect(button('Registruj se'), findsOneWidget);
    expect(find.byType(TavliNavigation), findsNothing);
    expect(find.text('Recepti'), findsNothing);
  });

  testTavli('nepoznata adresa: "Ne postoji nalog", nalog se ne pravi', (
    tester,
  ) async {
    final app = await pumpTavli(tester, signedIn: false);
    await enterEmail(tester, 'nova@mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    expect(find.text('Ne postoji nalog sa ovom adresom.'), findsOneWidget);
    expect(find.text('Proveri adresu ili napravi nov nalog.'), findsOneWidget);
    expect(field('E-pošta'), findsOneWidget);
    expect(app.backend.server.users, isNot(contains('nova@mail.com')));
    expect(app.backend.auth.sentCodes, isEmpty);

    // "Registruj se" nosi upisanu adresu.
    await tapButton(tester, 'Registruj se');
    expect(find.text('Napravi nalog'), findsWidgets);
    final input = tester.widget<TextField>(field('E-pošta'));
    expect(input.controller!.text, 'nova@mail.com');
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
    expect(find.text('Upiši kod'), findsOneWidget);
    expect(
      find.text('Poslali smo kod na ana@mail.com. Važi 10 minuta.'),
      findsOneWidget,
    );
    // Kanvas: na koraku sa kodom gore je "Nazad" umesto znaka.
    expect(button('Nazad'), findsOneWidget);
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
      expect(
        find.text('Poslali smo kod na ana@mail.com. Važi 10 minuta.'),
        findsOneWidget,
      );
    });
  }

  testTavli('greška pri slanju koda ostaje na prvom koraku', (tester) async {
    final app = await pumpTavli(tester, signedIn: false, backend: withAna());
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

  for (final (platform, message) in [
    (
      TargetPlatform.linux,
      'Bezbedno skladište sesije nije dostupno. Proveri da li je sistemski keyring pokrenut i otključan, pa pokušaj ponovo.',
    ),
    (TargetPlatform.windows, 'Funkcija nije dostupna na ovom uređaju.'),
  ]) {
    testTavli('odbijeno čuvanje sesije na ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final app = await toCodeStep(tester);
      app.secrets.deniedWrites.add(SessionStore.key);

      await tester.enterText(field('Kod iz poruke'), FakeServer.code);
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(
        find.text('Poslali smo kod na ana@mail.com. Važi 10 minuta.'),
        findsOneWidget,
      );
      expect(app.backend.auth.current, isNull);
      expect(app.secrets.values, isEmpty);
    });
  }

  testTavli('"Pošalji ponovo" posle 30 s', (tester) async {
    final app = await toCodeStep(tester);
    expect(find.text('Pošalji ponovo (za 30 s)'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(button('Pošalji ponovo (za 30 s)'))
          .onPressed,
      isNull,
    );

    app.now = app.now.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Pošalji ponovo (za 18 s)'), findsOneWidget);

    app.now = app.now.add(const Duration(seconds: 18));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<ButtonStyleButton>(button('Pošalji ponovo')).onPressed,
      isNotNull,
    );
    await tester.tap(button('Pošalji ponovo'));
    await tester.pumpAndSettle();
    expect(app.backend.auth.sentCodes, ['ana@mail.com', 'ana@mail.com']);
    expect(find.text('Pošalji ponovo (za 30 s)'), findsOneWidget);
  });

  for (final back in ['Promeni e-poštu', 'Nazad']) {
    testTavli('"$back" vraća na prvi korak', (tester) async {
      await toCodeStep(tester);
      await tester.tap(button(back));
      await tester.pumpAndSettle();
      expect(field('E-pošta'), findsOneWidget);
      expect(field('Kod iz poruke'), findsNothing);
    });
  }

  testTavli('istekao link iz mejla: poruka na prijavi', (tester) async {
    final app = await pumpTavli(tester, signedIn: false);
    app.links.add(Uri.parse('tavli://auth-callback?code=star'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Link je istekao ili je već iskorišćen. Upiši kod iz mejla ili '
        'pošalji mejl ponovo.',
      ),
      findsOneWidget,
    );
    expect(app.secrets.values, isEmpty);
  });

  testTavli('naslov je na istoj visini na svim koracima', (tester) async {
    await pumpTavli(tester, signedIn: false, backend: withAna());
    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    final title = top('Prijava');

    await tapButton(tester, 'Registruj se');
    expect(top('Napravi nalog'), title);

    await tapButton(tester, 'Prijavi se');
    await enterEmail(tester, 'ana@mail.com');
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    // Gore je "Nazad" umesto znaka, a naslov ostaje na istom mestu.
    expect(top('Upiši kod'), title);
  });

  testTavli('duboki link /plan: posle prijave otvara Plan', (tester) async {
    final backend = withAna();
    final uid = backend.server.users['ana@mail.com']!;
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
      // Obrazac je najviše 420 širok i ne izlazi iz ekrana.
      final code = tester.getRect(field('Kod iz poruke'));
      expect(code.width, lessThanOrEqualTo(420));
      expect(code.right, lessThanOrEqualTo(size.width));
    });
  }
}
