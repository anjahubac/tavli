import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/account_api.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/ai/ai_models.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  const dialogText =
      'Trajno se brišu tvoj profil, domaćinstvo i svi podaci u njemu '
      '(recepti, liste, ostava, planovi, ocene, fotografije), na serveru i '
      'na ovom uređaju, kao i tvoji AI ključevi na ovom uređaju. Ovo ne '
      'može da se poništi.';

  Finder redButton() => find.descendant(
    of: find.byType(AlertDialog),
    matching: button('Obriši nalog'),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Obriši nalog'));
    await tester.tap(find.text('Obriši nalog'));
    await tester.pumpAndSettle();
  }

  testTavli('dijalog: tekst, crveno dugme, "Odustani" ne menja ništa', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/profile');
    await openDialog(tester);
    expect(find.text('Obrisati nalog?'), findsOneWidget);
    expect(find.text(dialogText), findsOneWidget);
    final style = tester.widget<FilledButton>(redButton()).style!;
    final context = tester.element(find.byType(AlertDialog));
    expect(
      style.backgroundColor!.resolve({}),
      Theme.of(context).colorScheme.error,
    );
    await tester.tap(button('Odustani'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(app.backend.server.profiles, contains(app.session.userId));
  });

  testTavli('brisanje: "Prijava" sa porukom, ništa ne ostaje', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/profile',
      recipes: [sampleRecipe('r1', 'Sarma')],
    );
    await app.keys.add(AIProvider.groq, 'gsk_fake_key');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(app.backend.server.table('recipes'), isNotEmpty);

    await openDialog(tester);
    await tester.tap(redButton());
    await tester.pumpAndSettle();

    expect(find.text('Prijava'), findsOneWidget);
    expect(find.text('Nalog je obrisan.'), findsOneWidget);
    expect(app.backend.server.profiles, isNot(contains(app.session.userId)));
    expect(app.backend.server.table('recipes'), isEmpty);
    expect(await app.db.select(app.db.recipes).get(), isEmpty);
    expect(await app.db.select(app.db.accounts).get(), isEmpty);
    expect(await app.keys.list(), isEmpty);
    expect(app.secrets.values.containsKey(SessionStore.key), isFalse);

    // Ista adresa ponovo: nov prazan nalog i korak sa imenom.
    await tester.enterText(
      find.widgetWithText(TextField, 'E-pošta'),
      testEmail,
    );
    await tester.pump();
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Kod iz poruke'),
      FakeServer.code,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kako da te zovemo?'), findsOneWidget);
  });

  for (final (name, failure, text) in [
    (
      'bez mreže',
      null,
      'Nema interneta. Nalog može da se obriše samo uz vezu.',
    ),
    (
      'greška servera',
      const DeleteServerError(),
      'Brisanje nije uspelo. Pokušaj ponovo.',
    ),
  ]) {
    testTavli('$name: poruka i ostaje prijavljen', (tester) async {
      final app = await pumpTavli(
        tester,
        location: '/profile',
        recipes: [sampleRecipe('r1', 'Sarma')],
      );
      if (failure == null) {
        app.backend.server.offline = true;
      } else {
        app.backend.accounts.deleteFails = failure;
      }
      await openDialog(tester);
      await tester.tap(redButton());
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      expect(find.text('Ana Petrović'), findsOneWidget);
      expect(await app.db.select(app.db.recipes).get(), hasLength(1));
      expect(app.secrets.values[SessionStore.key], isNotNull);
    });
  }
}
