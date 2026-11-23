import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

/// Ana je član Markovog domaćinstva „Kuća Horvat“.
({FakeBackend backend, String ana, String marko}) sharedHome() {
  final backend = FakeBackend();
  final server = backend.server;
  final ana = server.userFor(testEmail);
  final marko = server.userFor('marko@tavli.test');
  server.profiles[ana]!['display_name'] = 'Ana Petrović';
  final home = server.households[marko]!;
  server.table('households')[home]!['name'] = 'Kuća Horvat';
  server.households[ana] = home;
  server.roles[ana] = 'member';
  return (backend: backend, ana: ana, marko: marko);
}

const removedTitle = 'Više nisi u domaćinstvu „Kuća Horvat“';

void main() {
  testTavli('posle uklanjanja povratak u aplikaciju prikazuje obaveštenje', (
    tester,
  ) async {
    final (:backend, :ana, :marko) = sharedHome();
    final app = await pumpTavli(tester, location: '/profile', backend: backend);
    await (app.db.update(
      app.db.accounts,
    )..where((a) => a.userId.equals(ana))).write(
      const AccountsCompanion(
        householdName: Value('Kuća Horvat'),
        role: Value('member'),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    expect(find.text(removedTitle), findsNothing);

    // Marko uklanja Anu: server joj pravi novo lično domaćinstvo i zapis.
    backend.server.removals[ana] = backend.server.households[marko]!;
    backend.server.households[ana] = 'home-removed';
    backend.server.roles[ana] = 'owner';
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();

    expect(find.text(removedTitle), findsOneWidget);
    expect(
      find.textContaining('Sada si u svom domaćinstvu „Moje domaćinstvo“.'),
      findsOneWidget,
    );
    await tester.tap(find.text('U redu'));
    await tester.pumpAndSettle();
    expect(find.text(removedTitle), findsNothing);
    expect(container.read(accountScopeProvider)?.householdId, 'home-removed');
    expect(backend.server.households[marko], isNot('home-removed'));

    // Obaveštenje se prikazuje samo jednom.
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    expect(find.text(removedTitle), findsNothing);
  });

  testTavli('uklanjanje primećeno pri pokretanju prikazuje obaveštenje', (
    tester,
  ) async {
    final backend = FakeBackend();
    final ana = backend.server.userFor(testEmail);
    backend.server.profiles[ana]!['display_name'] = 'Ana Petrović';
    backend.server.removals[ana] = 'home-old';
    await pumpTavli(
      tester,
      location: '/profile',
      backend: backend,
      // Keš na uređaju još pamti staro članstvo.
      setup: (db) =>
          (db.update(db.accounts)..where((a) => a.userId.equals(ana))).write(
            const AccountsCompanion(
              householdId: Value('home-old'),
              householdName: Value('Kuća Horvat'),
              role: Value('member'),
            ),
          ),
    );
    expect(find.text(removedTitle), findsOneWidget);
  });

  testTavli('novo domaćinstvo sa drugog uređaja ne prikazuje obaveštenje', (
    tester,
  ) async {
    final (:backend, :ana, marko: _) = sharedHome();
    final app = await pumpTavli(tester, location: '/profile', backend: backend);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    // Ana je sama napravila novo domaćinstvo: uloga vlasnika, bez zapisa.
    backend.server.households[ana] = 'home-own-new';
    backend.server.roles[ana] = 'owner';
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    expect(find.textContaining('Više nisi u domaćinstvu'), findsNothing);
    expect(app.scope.householdId, 'home-own-new');
  });

  testTavli('prelazak sa drugog uređaja ne prikazuje obaveštenje', (
    tester,
  ) async {
    final (:backend, :ana, marko: _) = sharedHome();
    final app = await pumpTavli(tester, location: '/profile', backend: backend);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final other = backend.server.userFor('petar@tavli.test');
    backend.server.households[ana] = backend.server.households[other]!;
    backend.server.roles[ana] = 'member';
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    expect(find.textContaining('Više nisi u domaćinstvu'), findsNothing);
    expect(
      container.read(accountScopeProvider)?.householdId,
      backend.server.households[other],
    );
    expect(app.scope.householdId, backend.server.households[other]);
  });
}
