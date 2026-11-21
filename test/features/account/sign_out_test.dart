import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

void main() {
  const signOutText = 'Tvoji podaci ostaju sačuvani u nalogu.';
  const waitingText =
      'Neke izmene još nisu poslate. Poslaćemo ih kada se ponovo prijaviš '
      'na ovom uređaju.';

  Finder tab(String label) => find.descendant(
    of: find.byType(TavliNavigation),
    matching: find.text(label),
  );

  // Profil je iznad tabova: nazad vodi na Početnu, avatar ga ponovo otvara.
  // Lonac na Početnoj krčka u petlji, pa bez pumpAndSettle.
  Future<void> leaveProfile(WidgetTester tester) async {
    await tester.tap(iconButton('Nazad'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TavliAppBar),
        matching: find.bySemanticsLabel('Profil'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSignOut(WidgetTester tester) async {
    await tester.tap(find.text('Odjavi se'));
    await tester.pumpAndSettle();
  }

  Future<void> signInWithCode(WidgetTester tester, String email) async {
    await tester.enterText(textField('E-pošta'), email);
    await tester.pump();
    await tester.tap(button('Pošalji kod'));
    await tester.pumpAndSettle();
    await tester.enterText(textField('Kod iz poruke'), FakeServer.code);
    await tester.pumpAndSettle();
  }

  testTavli('dijalog: "Odustani" ne menja ništa', (tester) async {
    final app = await pumpTavli(tester, location: '/profile');
    await openSignOut(tester);
    expect(find.text('Odjaviti se?'), findsOneWidget);
    expect(find.text(signOutText), findsOneWidget);
    expect(find.textContaining(waitingText), findsNothing);
    await tester.tap(button('Odustani'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(app.secrets.values[SessionStore.key], isNotNull);
  });

  testTavli('izmene koje čekaju: dijalog to kaže', (tester) async {
    final app = await pumpTavli(tester, location: '/profile');
    app.backend.server.offline = true;
    await tester.tap(find.text('Izmeni ime'));
    await tester.pumpAndSettle();
    await tester.tap(button('Sačuvaj'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await openSignOut(tester);
    expect(find.textContaining(waitingText), findsOneWidget);
  });

  testTavli('odjava: samo sesija se briše; drugi nalog ne vidi ništa; '
      'povratak vraća sve i šalje izmenu', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/profile',
      recipes: [sampleRecipe('r1', 'Sarma')],
    );
    await app.keys.add(AIProvider.groq, 'gsk_fake_test_key');
    await app.db
        .into(app.db.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'theme', value: 'dark'));
    await app.db
        .into(app.db.modelStatuses)
        .insert(ModelStatusesCompanion.insert(provider: 'gemini', model: 'm'));

    // Izmena bez mreže pa odjava.
    app.backend.server.offline = true;
    await tester.tap(find.text('Izmeni ime'));
    await tester.pumpAndSettle();
    await tester.enterText(textField('Ime'), 'Ana P.');
    await tester.tap(button('Sačuvaj'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await openSignOut(tester);
    await tester.tap(button('Odjavi se'));
    await tester.pumpAndSettle();

    expect(find.text('Prijava'), findsOneWidget);
    expect(app.secrets.values.containsKey(SessionStore.key), isFalse);
    expect(await app.db.select(app.db.recipes).get(), hasLength(1));
    expect(await app.db.select(app.db.syncOutbox).get(), isNotEmpty);
    expect(await app.keys.list(), hasLength(1));
    expect(await app.db.select(app.db.appSettings).get(), isNotEmpty);
    expect(await app.db.select(app.db.modelStatuses).get(), hasLength(1));

    // Drugi nalog na istom uređaju.
    app.backend.server.offline = false;
    await signInWithCode(tester, 'bojan@mail.com');
    await tester.enterText(find.widgetWithText(TextField, 'Ime'), 'Bojan');
    await tester.pump();
    await tester.tap(button('Nastavi'));
    await tester.pumpAndSettle();
    // Posle prijave nazad na traženu stranu ("Profil").
    expect(find.text('Bojan'), findsOneWidget);
    await leaveProfile(tester);
    await tester.tap(tab('Recepti'));
    await tester.pumpAndSettle();
    expect(find.text('Sarma'), findsNothing);
    await openProfile(tester);
    expect(find.text('Ana P.'), findsNothing);
    // Izmena prvog naloga još nije poslata.
    expect(
      app.backend.server.profiles[app.session.userId]!['display_name'],
      isNot('Ana P.'),
    );

    // Nazad na prvi nalog: podaci odmah, izmena koja je čekala se šalje.
    await openSignOut(tester);
    await tester.tap(button('Odjavi se'));
    await tester.pumpAndSettle();
    await signInWithCode(tester, testEmail);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(tab('Recepti'));
    await tester.pumpAndSettle();
    expect(find.text('Sarma'), findsWidgets);
    expect(
      app.backend.server.profiles[app.session.userId]!['display_name'],
      'Ana P.',
    );
  });
}
