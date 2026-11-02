import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/photo_sync.dart';
import 'package:tavli/sync/sync_engine.dart';
import 'package:tavli/sync/sync_remote.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';
import '../helpers/fake_timers.dart';

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late AccountScope scope;
  late SyncedWriter writer;
  late FakeTimers timers;
  late SyncEngine engine;
  late List<SyncStatus> seen;
  var unauthorized = 0;
  var refreshOk = true;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    timers = FakeTimers();
    unauthorized = 0;
    refreshOk = true;
    final s = await backend.auth.verifyCode('ana@mail.com', FakeServer.code);
    scope = AccountScope(
      userId: s.userId,
      householdId: backend.server.households[s.userId]!,
    );
    engine = SyncEngine(
      db: db,
      scope: scope,
      uploader: Uploader(
        db: db,
        remote: backend.sync,
        photos: backend.photos,
        photoStore: FakePhotoStore(),
        scope: scope,
        refreshSession: () async => refreshOk,
      ),
      timer: timers.call,
      onUnauthorized: () async => unauthorized++,
    );
    writer = SyncedWriter(db, accountId: scope.userId, onChange: engine.kick);
    seen = [];
    engine.watchStatus().listen(seen.add);
  });
  tearDown(() async {
    engine.stop();
    await pumpQueue();
    await db.close();
  });

  Future<void> addRecipe(String id) async {
    await db
        .into(db.recipes)
        .insertOnConflictUpdate(
          RecipesCompanion.insert(
            id: id,
            title: id,
            servings: 2,
            source: 'manual',
            ingredientsJson: '[]',
            stepsJson: '[]',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            householdId: Value(scope.householdId),
          ),
        );
    await writer.upsert('recipe', id);
  }

  test('pokretanje šalje sve što čeka', () async {
    await addRecipe('a');
    timers.pending.clear(); // izmena pre pokretanja
    await engine.onStart();
    expect(backend.server.table('recipes').keys, ['a']);
    expect(engine.status, isA<AllSaved>());
    expect(seen.whereType<Sending>(), isNotEmpty);
  });

  test('prekinuto slanje (sending) ponovo čeka posle pokretanja', () async {
    await addRecipe('a');
    await db
        .update(db.syncOutbox)
        .write(const SyncOutboxCompanion(state: Value(OutboxState.sending)));
    await engine.onStart();
    expect(backend.server.table('recipes').keys, ['a']);
  });

  test('lokalna izmena: slanje posle 1 s pauze', () async {
    await addRecipe('a');
    await addRecipe('b');
    expect(timers.durations, [const Duration(seconds: 1)]);
    await pumpQueue();
    expect(engine.status, isA<Waiting>());
    expect(backend.server.table('recipes'), isEmpty);

    await timers.fire();
    expect(backend.server.table('recipes'), hasLength(2));
    expect(backend.server.calls, ['upsert:recipes:2']);
    expect(engine.status, isA<AllSaved>());
  });

  test('bez mreže: "čeka slanje" i ponovo posle 5, 10, pa 30 s', () async {
    backend.server.offline = true;
    await addRecipe('a');
    await addRecipe('b');
    await timers.fire();
    expect(engine.status, isA<Waiting>());
    expect((engine.status as Waiting).count, 2);
    expect(timers.durations, [const Duration(seconds: 5)]);

    await timers.fire();
    expect(timers.durations, [const Duration(seconds: 10)]);
    await timers.fire();
    expect(timers.durations, [const Duration(seconds: 30)]);
    await timers.fire();
    expect(timers.durations, [const Duration(seconds: 30)]);

    backend.server.offline = false;
    await timers.fire();
    expect(engine.status, isA<AllSaved>());
    expect(timers.pending, isEmpty);
    expect(backend.server.table('recipes'), hasLength(2));
  });

  test('odbijena izmena ima prednost u prikazu', () async {
    backend.server.rejectIds.add('a');
    await addRecipe('a');
    await engine.push();
    expect(engine.status, isA<Rejected>());
    expect((engine.status as Rejected).count, 1);
    backend.server.offline = true;
    await addRecipe('b');
    await timers.fire();
    expect(engine.status, isA<Rejected>());
  });

  test('povratak u aplikaciju šalje', () async {
    await addRecipe('a');
    timers.pending.clear();
    await engine.onResume();
    expect(backend.server.table('recipes').keys, ['a']);
  });

  test('odbijena sesija i posle obnove: javlja kontroleru', () async {
    refreshOk = false;
    await addRecipe('a');
    backend.server.failures.addAll(const [
      UnauthorizedSyncError(),
      UnauthorizedSyncError(),
    ]);
    await timers.fire();
    expect(unauthorized, 1);
    expect(backend.server.table('recipes'), isEmpty);
  });

  test('stop gasi tajmere i slanje', () async {
    await addRecipe('a');
    engine.stop();
    expect(timers.pending, isEmpty);
    await engine.push();
    expect(backend.server.table('recipes'), isEmpty);
  });

  group('preuzimanje', () {
    late SyncEngine full;
    late List<SyncPhase?> phases;
    var now = DateTime.utc(2026, 11, 1, 12);

    setUp(() async {
      now = DateTime.utc(2026, 11, 1, 12);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              userId: scope.userId,
              email: 'ana@mail.com',
              householdId: scope.householdId,
              householdName: 'Moje domaćinstvo',
              role: 'owner',
              createdAt: now,
            ),
          );
      full = SyncEngine(
        db: db,
        scope: scope,
        uploader: Uploader(
          db: db,
          remote: backend.sync,
          photos: backend.photos,
          photoStore: FakePhotoStore(),
          scope: scope,
          refreshSession: () async => true,
        ),
        downloader: Downloader(db: db, remote: backend.sync, scope: scope),
        photoSync: PhotoSync(
          db: db,
          remote: backend.photos,
          store: FakePhotoStore(),
          scope: scope,
        ),
        timer: timers.call,
        clock: () => now,
      );
      writer = SyncedWriter(db, accountId: scope.userId, onChange: full.kick);
      phases = [];
      full.watchPhase().listen(phases.add);
      backend.server.upsert('pantry_items', [
        {
          'id': 'o1',
          'household_id': scope.householdId,
          'name': 'so',
          'category': 'ostalo',
          'added_at': '2026-10-30T10:00:00.000Z',
        },
      ], 'id');
    });
    tearDown(() => full.stop());

    Future<AccountRow> account() => db.select(db.accounts).getSingle();

    test('posle prijave: prvo slanje, pa celo preuzimanje', () async {
      await addRecipe('a');
      timers.pending.clear();
      backend.server.calls.clear();
      await full.onStart();
      expect(backend.server.calls.first, 'upsert:recipes:1');
      expect(backend.server.calls, contains('fetch:pantry_items'));
      expect(
        backend.server.calls.indexOf('upsert:recipes:1'),
        lessThan(backend.server.calls.indexOf('fetch:recipes')),
      );
      expect(await db.select(db.pantryItems).get(), hasLength(1));
      expect(phases, [null, SyncPhase.downloading, null]);
      final a = await account();
      expect(a.initialDownloadDone, isTrue);
      expect(a.lastPullAt!.isAtSameMomentAs(now), isTrue);
    });

    test('kasnije pokretanje: bez trake "Preuzimam…"', () async {
      await full.onStart();
      phases.clear();
      await full.onStart();
      expect(phases, isEmpty);
    });

    test('povratak u aplikaciju preuzima tek posle 15 minuta', () async {
      await full.onStart();
      backend.server.calls.clear();
      now = now.add(const Duration(minutes: 14));
      await full.onResume();
      expect(backend.server.calls.where((c) => c.startsWith('fetch')), isEmpty);
      now = now.add(const Duration(minutes: 1));
      await full.onResume();
      expect(backend.server.calls, contains('fetch:recipes'));
    });

    test(
      'bez mreže: preuzimanje ne javlja grešku, nastavlja se kasnije',
      () async {
        backend.server.offline = true;
        await full.onStart();
        expect(phases.last, isNull);
        expect((await account()).initialDownloadDone, isFalse);
        backend.server.offline = false;
        await full.onStart();
        expect((await account()).initialDownloadDone, isTrue);
      },
    );
  });
}
