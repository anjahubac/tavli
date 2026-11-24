import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

const _skip = 'Pređi bez nesinhronizovanih izmena';
const _wait = 'Nastavi da čekaš';

/// Profil > „Pridruži se novom domaćinstvu“: izbor novog ili postojećeg.
Future<void> openHouseholdChoice(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Pridruži se novom domaćinstvu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pridruži se novom domaćinstvu'));
  await tester.pumpAndSettle();
}

/// Profil > „Pridruži se novom domaćinstvu“ > „Pridruži se postojećem
/// domaćinstvu“ > kod > „Nastavi“.
Future<void> enterInviteCode(WidgetTester tester) async {
  await openHouseholdChoice(tester);
  await tapButton(tester, 'Pridruži se postojećem domaćinstvu');
  await tester.enterText(textField('Kod pozivnice'), '0123-4567-89ab');
  await tester.pump();
  await tapButton(tester, 'Nastavi');
}

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
    await enterInviteCode(tester);
    expect(find.text('Pozvan si u'), findsOneWidget);
    expect(find.text('Zajedničko domaćinstvo'), findsOneWidget);
    if (useSync) backend.server.offline = true;
    await app.repo.create(sampleRecipe('old-draft', 'Nesinhronizovan recept'));
    await tapButton(tester, 'Da, bez recepata');
    // Poslednji član: brisanje se potvrđuje pre prelaska.
    expect(find.text('Trajno brisanje domaćinstva'), findsWidgets);
    await tapButton(tester, 'Pridruži se');
    expect(backend.accounts.joinCalls, 0, reason: 'bez potvrde nema prelaska');
    await tester.ensureVisible(find.text('Razumem da je brisanje trajno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Razumem da je brisanje trajno'));
    await tester.pump();
    await tapButton(tester, 'Pridruži se');
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

  testTavli('„Ne, ostani ovde“ ne menja domaćinstvo', (tester) async {
    final backend = FakeBackend();
    backend.accounts.joinTargetHousehold = 'destination';
    final app = await pumpTavli(tester, location: '/profile', backend: backend);
    final home = app.scope.householdId;
    await enterInviteCode(tester);
    await tapButton(tester, 'Ne, ostani ovde');
    expect(find.text('Pozvan si u'), findsNothing);
    expect(backend.accounts.joinCalls, 0);
    expect(app.scope.householdId, home);
  });

  testTavli('kada članovi ostaju, prelazak ne traži potvrdu brisanja', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..accounts.joinTargetHousehold = 'destination'
      ..accounts.joinRequiresAck = false;
    final app = await pumpTavli(
      tester,
      location: '/profile',
      backend: backend,
      overrides: [syncEngineProvider.overrideWithValue(null)],
    );
    await enterInviteCode(tester);
    expect(
      find.textContaining('ostaju u domaćinstvu „Moje domaćinstvo“'),
      findsOneWidget,
    );
    await tapButton(tester, 'Da, ponesi moje recepte');
    expect(find.text('Trajno brisanje domaćinstva'), findsNothing);
    expect(backend.accounts.joinCalls, 1);
    expect(backend.accounts.lastJoinAck, 0);
    expect(app.scope.householdId, 'destination');
  });

  testTavli(
    'neispravan kod ne šalje zahtev; nedostupna pozivnica se objašnjava',
    (tester) async {
      final backend = FakeBackend();
      await pumpTavli(
        tester,
        size: wide,
        location: '/profile',
        backend: backend,
      );
      await openHouseholdChoice(tester);
      await tapButton(tester, 'Pridruži se postojećem domaćinstvu');
      // Širok ekran: dijalog umesto donjeg lista.
      expect(find.byType(TavliSheet), findsNothing);
      expect(find.byType(TavliDialog<void>), findsOneWidget);
      await tester.enterText(textField('Kod pozivnice'), 'ABC');
      await tester.pump();
      expect(tester.widget<FilledButton>(button('Nastavi')).onPressed, isNull);
      await tester.enterText(textField('Kod pozivnice'), '0123 4567 89AB');
      await tester.pump();
      await tapButton(tester, 'Nastavi');
      expect(
        find.text('Pozivnica trenutno nije dostupna. Pokušaj ponovo.'),
        findsOneWidget,
      );
    },
  );

  group('Kreiraj novo domaćinstvo', () {
    for (final size in [phone, wide]) {
      testTavli('naziv, pa ista potvrda kao pridruživanje (${size.width} px)', (
        tester,
      ) async {
        final backend = FakeBackend()..accounts.joinRequiresAck = false;
        final app = await pumpTavli(
          tester,
          size: size,
          location: '/profile',
          backend: backend,
          overrides: [syncEngineProvider.overrideWithValue(null)],
        );
        await openHouseholdChoice(tester);
        expect(find.text('Kreiraj novo domaćinstvo'), findsOneWidget);
        expect(find.text('Pridruži se postojećem domaćinstvu'), findsOneWidget);
        await tapButton(tester, 'Kreiraj novo domaćinstvo');

        // Samo naziv: nema koda ni skeniranja.
        expect(find.text('Novo domaćinstvo'), findsOneWidget);
        expect(find.text('Kod pozivnice'), findsNothing);
        expect(find.text('Skeniraj QR kod'), findsNothing);
        expect(
          tester.widget<FilledButton>(button('Nastavi')).onPressed,
          isNull,
        );
        await tester.enterText(textField('Naziv domaćinstva'), '  Vikendica ');
        await tester.pump();
        await tapButton(tester, 'Nastavi');

        expect(backend.accounts.prepareNewCalls, 1);
        expect(find.text('Novo domaćinstvo'), findsOneWidget);
        expect(find.text('Vikendica'), findsOneWidget);
        expect(
          find.text('Da li ste sigurni da želite da napustite domaćinstvo?'),
          findsOneWidget,
        );
        await tapButton(tester, 'Da, ponesi moje recepte');

        expect(backend.accounts.joinCalls, 1);
        expect(app.scope.householdId, startsWith('new-'));
        expect(tester.takeException(), isNull);
      });
    }

    testTavli('poslednji član potvrđuje brisanje kao kod pridruživanja', (
      tester,
    ) async {
      final backend = FakeBackend();
      final app = await pumpTavli(
        tester,
        location: '/profile',
        backend: backend,
        overrides: [syncEngineProvider.overrideWithValue(null)],
      );
      final home = app.scope.householdId;
      await openHouseholdChoice(tester);
      await tapButton(tester, 'Kreiraj novo domaćinstvo');
      await tester.enterText(textField('Naziv domaćinstva'), 'Vikendica');
      await tester.pump();
      await tapButton(tester, 'Nastavi');
      await tapButton(tester, 'Da, bez recepata');
      expect(find.text('Trajno brisanje domaćinstva'), findsWidgets);
      await tapButton(tester, 'Odustani');
      expect(backend.accounts.joinCalls, 0);
      expect(app.scope.householdId, home);
    });

    testTavli('bez interneta naziv ostaje i greška se objašnjava', (
      tester,
    ) async {
      final backend = FakeBackend();
      final app = await pumpTavli(
        tester,
        location: '/profile',
        backend: backend,
      );
      final home = app.scope.householdId;
      await openHouseholdChoice(tester);
      await tapButton(tester, 'Kreiraj novo domaćinstvo');
      backend.server.offline = true;
      await tester.enterText(textField('Naziv domaćinstva'), 'Vikendica');
      await tester.pump();
      await tapButton(tester, 'Nastavi');
      expect(
        find.text('Nema interneta. Za novo domaćinstvo je potrebna veza.'),
        findsOneWidget,
      );
      expect(backend.accounts.joinCalls, 0);
      expect(app.scope.householdId, home);
    });

    testTavli('„Odustani“ u izboru ne otvara ništa', (tester) async {
      final backend = FakeBackend();
      await pumpTavli(tester, location: '/profile', backend: backend);
      await openHouseholdChoice(tester);
      await tapButton(tester, 'Odustani');
      expect(find.text('Kreiraj novo domaćinstvo'), findsNothing);
      expect(backend.accounts.prepareNewCalls, 0);
    });
  });
}
