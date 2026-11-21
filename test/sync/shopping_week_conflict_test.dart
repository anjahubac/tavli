import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/sync_engine.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';

void main() {
  late FakeBackend backend;
  late AccountScope scope;
  late AppDatabase a;
  late AppDatabase b;
  final now = DateTime.utc(2026, 11);
  final monday = CivilDate(2026, 11, 2);
  final week = WeekPeriod(1, DateRange(monday, monday.addDays(6)));

  SyncedWriter writer(AppDatabase db) =>
      SyncedWriter(db, accountId: scope.userId, clock: () => now);
  ShoppingRepository shopping(AppDatabase db) => ShoppingRepository(
    db,
    scope: scope,
    writer: writer(db),
    clock: () => now,
  );
  Uploader uploader(AppDatabase db) => Uploader(
    db: db,
    remote: backend.sync,
    photos: backend.photos,
    photoStore: FakePhotoStore(),
    scope: scope,
    refreshSession: () async => true,
    clock: () => now,
  );
  Downloader downloader(AppDatabase db) => Downloader(
    db: db,
    remote: backend.sync,
    scope: scope,
    pageSize: 1,
    overlap: Duration.zero,
  );

  setUp(() async {
    backend = FakeBackend();
    final session = await backend.auth.verifyCode(
      'week@example.test',
      FakeServer.code,
    );
    scope = AccountScope(
      userId: session.userId,
      householdId: backend.server.households[session.userId]!,
    );
    // Separate executors model two devices. The app also uses a SQLite isolate.
    final oldWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = oldWarningSetting;
    });
    final directory = await Directory.systemTemp.createTemp('tavli-week-sync-');
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(
      NativeDatabase.createInBackground(File('${directory.path}/cache.sqlite')),
    );
    addTearDown(() async {
      await a.close();
      await b.close();
      await directory.delete(recursive: true);
    });
    for (final db in [a, b]) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              userId: scope.userId,
              email: 'week@example.test',
              householdId: scope.householdId,
              householdName: 'Test',
              role: 'owner',
              createdAt: now,
            ),
          );
    }

    backend.server.upsert('meal_plans', [
      {
        'id': 'plan',
        'household_id': scope.householdId,
        'start_date': monday.toString(),
        'end_date': week.range.end.toString(),
        'meal_types': ['lunch'],
        'use_pantry': false,
        'created_at': now.toIso8601String(),
      },
    ], 'id');
    await downloader(a).run();
    await downloader(b).run();
  });

  Future<void> insertLegacyWeek(AppDatabase db, String id) => db
      .into(db.shoppingLists)
      .insert(
        ShoppingListsCompanion.insert(
          id: id,
          name: 'Nedelja 1',
          mealPlanId: const Value('plan'),
          week: const Value(1),
          createdAt: now,
          householdId: Value(scope.householdId),
          periodStart: Value(monday.toWire()),
          periodEnd: Value(week.range.end.toWire()),
        ),
      );

  Future<void> expectBothItems(AppDatabase db, String canonical) async {
    expect((await db.select(db.shoppingLists).getSingle()).id, canonical);
    expect(
      (await shopping(db).listItems(canonical)).map((item) => item.name),
      unorderedEquals(['Mleko', 'Hleb']),
    );
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  }

  for (final aFirst in [true, false]) {
    test(
      'new offline weeks converge when ${aFirst ? 'A' : 'B'} reconnects first',
      () async {
        final aId = await shopping(a).weekList('plan', week);
        final bId = await shopping(b).weekList('plan', week);
        expect(aId, bId);
        await shopping(a).addManual(aId, 'Mleko');
        await shopping(b).addManual(bId, 'Hleb');

        final first = aFirst ? a : b;
        final second = aFirst ? b : a;
        expect((await uploader(first).run()).rejected, 0);
        final created = backend.server.rows('shopping_lists').single;
        expect((await uploader(second).run()).rejected, 0);
        expect(backend.server.rows('shopping_lists').single, created);

        backend.server.upsert('shopping_lists', [
          {'id': aId, 'name': 'Noviji naziv'},
        ], 'id');
        final newer = backend.server.rows('shopping_lists').single;
        await writer(first).upsert('shopping_list', aId);
        expect((await uploader(first).run()).rejected, 0);
        expect(backend.server.rows('shopping_lists').single, newer);
        for (final db in [a, b]) {
          expect((await downloader(db).run()).deferred, 0);
          await expectBothItems(db, aId);
        }
      },
    );
  }

  test(
    'an existing legacy ID adopts local items after a rejected upload',
    () async {
      await insertLegacyWeek(a, 'server-week');
      await writer(a).upsert('shopping_list', 'server-week');
      await shopping(a).addManual('server-week', 'Mleko');

      final bId = await shopping(b).weekList('plan', week);
      await shopping(b).addManual(bId, 'Hleb');
      expect((await uploader(a).run()).rejected, 0);

      final engine = SyncEngine(
        db: b,
        scope: scope,
        downloader: downloader(b),
        uploader: uploader(b),
      );
      addTearDown(engine.stop);
      expect((await uploader(b).run()).rejected, 2);
      await engine.pull();
      await expectBothItems(b, 'server-week');
      await downloader(a).run();
      await expectBothItems(a, 'server-week');
    },
  );

  test('an unresolved conflict leaves its cursor retryable while later downloads apply', () async {
    await insertLegacyWeek(a, 'server-week');
    await writer(a).upsert('shopping_list', 'server-week');
    await uploader(a).run();
    await insertLegacyWeek(b, 'local-week');

    backend.server.upsert('shopping_lists', [
      {
        'id': 'independent-list',
        'household_id': scope.householdId,
        'name': 'Ručna lista',
        'created_at': now.toIso8601String(),
      },
    ], 'id');
    backend.server.upsert('shopping_items', [
      {
        'id': 'dependent',
        'household_id': scope.householdId,
        'list_id': 'server-week',
        'name': 'Mleko',
        'category': 'ostalo',
        'is_bought': false,
        'is_manual': true,
      },
    ], 'id');
    backend.server.upsert('pantry_items', [
      {
        'id': 'pantry',
        'household_id': scope.householdId,
        'name': 'Brašno',
        'category': 'ostalo',
        'added_at': now.toIso8601String(),
      },
    ], 'id');
    // Lista u konfliktu i njena stavka.
    expect((await downloader(b).run()).deferred, 2);
    expect(
      (await b.select(b.shoppingLists).get()).map((list) => list.id),
      unorderedEquals(['local-week', 'independent-list']),
    );
    expect(await b.select(b.shoppingItems).get(), isEmpty);
    expect((await b.select(b.pantryItems).getSingle()).id, 'pantry');
    expect(
      await (b.select(
        b.syncCursors,
      )..where((t) => t.entity.equals('shopping_list'))).getSingleOrNull(),
      isNull,
    );

    await (b.delete(
      b.shoppingLists,
    )..where((t) => t.id.equals('local-week'))).go();
    expect((await downloader(b).run()).deferred, 0);
    expect((await b.select(b.shoppingItems).getSingle()).id, 'dependent');
    expect(
      (await b.select(b.shoppingLists).get()).map((list) => list.id),
      unorderedEquals(['server-week', 'independent-list']),
    );
  });

  test('a permanently deferred row still records the pull', () async {
    await insertLegacyWeek(a, 'server-week');
    await writer(a).upsert('shopping_list', 'server-week');
    await uploader(a).run();
    // Bez lokalnog kreiranja u redu za slanje: konflikt ostaje nerešen.
    await insertLegacyWeek(b, 'local-week');

    var clock = now;
    final engine = SyncEngine(
      db: b,
      scope: scope,
      downloader: downloader(b),
      uploader: uploader(b),
      clock: () => clock,
    );
    addTearDown(engine.stop);
    final phases = <SyncPhase?>[];
    engine.watchPhase().listen(phases.add);

    for (var pull = 0; pull < 2; pull++) {
      await engine.pull();
      final account = await b.select(b.accounts).getSingle();
      expect(account.initialDownloadDone, isTrue);
      expect(account.lastPullAt!.isAtSameMomentAs(clock), isTrue);
      expect(engine.pullDeferred, 1);
      expect(
        await (b.select(
          b.syncCursors,
        )..where((t) => t.entity.equals('shopping_list'))).getSingleOrNull(),
        isNull,
      );
      clock = clock.add(const Duration(minutes: 1));
    }
    expect(phases.where((p) => p == SyncPhase.downloading), hasLength(1));

    backend.server.calls.clear();
    await engine.onResume();
    expect(backend.server.calls.where((c) => c.startsWith('fetch')), isEmpty);
  });
}
