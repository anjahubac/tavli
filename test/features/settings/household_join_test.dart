import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/synced_writer.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

const _skip = 'Pređi bez nesinhronizovanih izmena';
const _wait = 'Nastavi da čekaš';

void main() {
  Future<TestApp> openJoin(
    WidgetTester tester, {
    Size size = phone,
    bool useSync = false,
  }) async {
    final backend = FakeBackend();
    backend.accounts.joinTargetHousehold = 'destination';
    final app = await pumpTavli(
      tester,
      size: size,
      location: '/profile',
      backend: backend,
      overrides: [if (!useSync) syncEngineProvider.overrideWithValue(null)],
    );
    await tester.ensureVisible(find.text('Pridruži se domaćinstvu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pridruži se domaćinstvu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '0123-4567-89AB');
    await tester.pump();
    await tester.ensureVisible(find.text('Proveri pozivnicu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proveri pozivnicu'));
    await tester.pumpAndSettle();
    expect(
      find.text('Prelaziš u domaćinstvo „Zajedničko domaćinstvo“.'),
      findsOneWidget,
    );
    if (useSync) backend.server.offline = true;
    await app.repo.create(sampleRecipe('old-draft', 'Nesinhronizovan recept'));
    await tester.ensureVisible(find.text('Da, bez recepata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Da, bez recepata'));
    await tester.pumpAndSettle();
    expect(find.text('Sinhronizujemo izmene…'), findsOneWidget);
    expect(find.text(_skip), findsNothing);
    expect(backend.accounts.joinCalls, 0);
    return app;
  }

  testTavli('skip se nudi posle 30 s i primenjuje tek posle potvrde servera', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = await openJoin(tester, size: const Size(320, 700));
    await tester.pump(const Duration(seconds: 29));
    expect(find.text(_skip), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_skip), findsOneWidget);
    await tester.ensureVisible(find.text(_wait));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_wait));
    await tester.pump();
    expect(find.text(_skip), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    final skip = find.text(_skip);
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();

    final row = await app.db.select(app.db.syncOutbox).getSingle();
    expect(app.backend.accounts.joinCalls, 1);
    expect(app.scope.householdId, 'destination');
    expect(row.state, OutboxState.quarantined);
    expect(find.text(_skip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testTavli(
    'čeka ponovno slanje i automatski nastavlja kada red više ne blokira',
    (tester) async {
      final app = await openJoin(tester, size: wide);
      await app.db
          .update(app.db.syncOutbox)
          .write(
            const SyncOutboxCompanion(
              state: Value(OutboxState.rejected),
              lastError: Value('42501'),
            ),
          );
      await tester.pumpAndSettle();

      expect(app.backend.accounts.joinCalls, 1);
      expect(app.scope.householdId, 'destination');
      expect(find.text(_skip), findsNothing);
      final row = await app.db.select(app.db.syncOutbox).getSingle();
      expect(row.lastError, '42501');
    },
  );

  testTavli('privremena greška se ponavlja i prelazak čeka uspešan upload', (
    tester,
  ) async {
    final app = await openJoin(tester, useSync: true);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(app.backend.accounts.joinCalls, 0);
    expect(app.backend.server.rows('recipes'), isEmpty);

    app.backend.server.offline = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(app.backend.accounts.joinCalls, 1);
    expect(app.backend.server.rows('recipes').single['id'], 'old-draft');
    expect(app.scope.householdId, 'destination');
  });
}
