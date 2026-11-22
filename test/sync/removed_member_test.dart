import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/sync/synced_writer.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

void main() {
  testTavli(
    'removed member: a denied write switches to the new household while open',
    (tester) async {
      final backend = FakeBackend();
      // The server has the name too, as after a real sign-up.
      final uid = backend.server.userFor(testEmail);
      backend.server.profiles[uid]!['display_name'] = 'Ana Petrović';
      final app = await pumpTavli(
        tester,
        location: '/profile',
        backend: backend,
      );
      expect(find.text('Moje domaćinstvo · Vlasnik'), findsOneWidget);

      // The owner removes the member on the server; the app is still open.
      backend.server.enforceMembership = true;
      backend.server.households[app.scope.userId] = 'new-home';
      backend.accounts.householdNames['new-home'] = 'Novo domaćinstvo';

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(recipeRepositoryProvider)
          .create(sampleRecipe('stale-edit', 'Izmena posle uklanjanja'));
      // Debounced push, the denial, then the membership check.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Novo domaćinstvo · Vlasnik'), findsOneWidget);
      final account = await app.db.select(app.db.accounts).getSingle();
      expect(account.householdId, 'new-home');
      expect(backend.server.rows('recipes'), isEmpty);
      final queued = await (app.db.select(
        app.db.syncOutbox,
      )..where((t) => t.recordId.equals('stale-edit'))).getSingle();
      expect(queued.state, OutboxState.quarantined);
    },
  );
}
