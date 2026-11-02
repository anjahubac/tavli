import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/session_store.dart';
import 'package:tavli/sync/sync_remote.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

void main() {
  const expiredText = 'Sesija je istekla. Prijavi se ponovo.';

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  testTavli('obnovljena sesija se tiho ponovo čuva', (tester) async {
    final app = await pumpTavli(tester);
    final before = app.secrets.values[SessionStore.key];
    app.backend.auth.current = app.session;
    await app.backend.auth.refresh();
    await tester.pumpAndSettle();
    expect(app.secrets.values[SessionStore.key], before);
    expect(currentTab(tester), 'Recepti');
    expect(app.backend.auth.refreshes, 1);
  });

  testTavli('odbijena obnova: "Prijava" sa porukom, keš i izmene ostaju', (
    tester,
  ) async {
    final backend = FakeBackend();
    final app = await pumpTavli(
      tester,
      backend: backend,
      recipes: [sampleRecipe('r1', 'Sarma')],
      setup: (_) async =>
          backend.server.revoked.add(backend.auth.sessionFor(testEmail).userId),
    );
    // Izmena koja čeka (server ne prima ništa od opozvane sesije).
    await tester.pumpAndSettle();
    expect(find.text('Prijava'), findsOneWidget);
    expect(find.text(expiredText), findsOneWidget);
    expect(app.secrets.values.containsKey(SessionStore.key), isFalse);
    expect(await app.db.select(app.db.recipes).get(), hasLength(1));
    expect(await app.db.select(app.db.syncOutbox).get(), isNotEmpty);
    expect(await app.db.select(app.db.accounts).get(), hasLength(1));
  });

  testTavli('nalog obrisan na drugom uređaju: briše se i njegov keš', (
    tester,
  ) async {
    final backend = FakeBackend();
    final app = await pumpTavli(
      tester,
      backend: backend,
      recipes: [sampleRecipe('r1', 'Sarma')],
      setup: (_) async {
        final uid = backend.auth.sessionFor(testEmail).userId;
        backend.server.deleteAccount(uid);
      },
    );
    await tester.pumpAndSettle();
    expect(find.text(expiredText), findsOneWidget);
    expect(await app.db.select(app.db.recipes).get(), isEmpty);
    expect(await app.db.select(app.db.accounts).get(), isEmpty);
  });

  testTavli('bez mreže: ostaje prijavljen, obnova pri povratku', (
    tester,
  ) async {
    final backend = FakeBackend()..server.offline = true;
    final app = await pumpTavli(tester, backend: backend);
    expect(currentTab(tester), 'Recepti');
    expect(app.secrets.values[SessionStore.key], isNotNull);

    // Mreža se vrati, ali je sesija u međuvremenu opozvana.
    backend.server.offline = false;
    backend.server.revoked.add(app.session.userId);
    await container(tester)
        .read(authControllerProvider.notifier)
        .restoreSession();
    await tester.pumpAndSettle();
    expect(find.text(expiredText), findsOneWidget);
  });

  testTavli('401 pri slanju i odbijena obnova: nazad na prijavu', (
    tester,
  ) async {
    final app = await pumpTavli(tester, location: '/profile');
    app.backend.server.revoked.add(app.session.userId);
    app.backend.auth.current = app.session;
    app.backend.server.failures.add(const UnauthorizedSyncError());
    await tester.tap(find.text('Izmeni ime'));
    await tester.pumpAndSettle();
    await tester.tap(button('Sačuvaj'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(expiredText), findsOneWidget);
    // Izmena ostaje i šalje se posle ponovne prijave istim nalogom.
    expect(await app.db.select(app.db.syncOutbox).get(), hasLength(1));
    app.backend.server.revoked.clear();
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
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ana Petrović'), findsOneWidget);
    expect(await app.db.select(app.db.syncOutbox).get(), isEmpty);
    expect(
      app.backend.server.profiles[app.session.userId]!['display_name'],
      'Ana Petrović',
    );
  });

  test('tekst poruke za istek sesije', () {
    expect(const SessionRevoked().toString(), 'SessionRevoked');
  });
}
