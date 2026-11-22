import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/food_matcher.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/sync_engine.dart';
import 'package:tavli/sync/sync_remote.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late AccountScope scope;
  late String hid;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    final s = await backend.auth.verifyCode('ana@mail.com', FakeServer.code);
    hid = backend.server.households[s.userId]!;
    scope = AccountScope(userId: s.userId, householdId: hid);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            userId: s.userId,
            email: 'ana@mail.com',
            householdId: hid,
            householdName: 'Moje domaćinstvo',
            role: 'owner',
            createdAt: DateTime.utc(2026),
          ),
        );
  });
  tearDown(() => db.close());

  Downloader downloader() =>
      Downloader(db: db, remote: backend.sync, scope: scope);

  void serverFood(String id, {String? household, String? withdrawnAt}) =>
      backend.server.upsert('foods', [
        {
          'id': id,
          'household_id': household,
          'slug': 'slug-$id',
          'name': 'naziv $id',
          'category': 'Ostalo',
          'base_unit': 'gram',
          'source': null,
          'reviewed_at': null,
          'withdrawn_at': withdrawnAt,
          'created_at': '2026-11-01T10:00:00.000Z',
        },
      ], 'id');

  void serverAlias(String id, String foodId, {String? household}) =>
      backend.server.upsert('food_aliases', [
        {
          'id': id,
          'food_id': foodId,
          'household_id': household,
          'alias': 'alias $id',
          'alias_normalized': 'alias $id',
          'withdrawn_at': null,
          'created_at': '2026-11-01T10:00:00.000Z',
        },
      ], 'id');

  Future<Set<String>> localFoods() async => {
    for (final r in await db.select(db.foods).get()) r.id,
  };
  Future<Set<String>> localAliases() async => {
    for (final r in await db.select(db.foodAliases).get()) r.id,
  };
  Future<Set<String>> catalogCursors() async => {
    for (final c in await db.select(db.syncCursors).get())
      if (c.entity == 'food' || c.entity == 'food_alias') c.entity,
  };

  SyncEngine engine() => SyncEngine(
    db: db,
    scope: scope,
    uploader: Uploader(
      db: db,
      remote: backend.sync,
      photos: backend.photos,
      photoStore: FakePhotoStore(),
      scope: scope,
      refreshSession: () async => false,
    ),
    downloader: downloader(),
  );

  test(
    'engine pamti nedostupan katalog i matcher ne koristi stari keš',
    () async {
      serverFood('f-shared');
      final sync = engine();
      addTearDown(sync.stop);
      final lookup = FoodLookupScope(householdId: hid);
      Future<FoodMatchResult> match(SyncEngine current) async =>
          (await current.catalogMatcher()).findByName(
            originalText: 'naziv f-shared',
            scope: lookup,
          );

      await sync.pull();
      expect(await match(sync), isA<Matched>());

      backend.server.missingTables.add('food_aliases');
      await sync.pull();
      expect(await localFoods(), {'f-shared'});
      expect(await match(sync), isA<Unresolved>());

      final restarted = engine();
      addTearDown(restarted.stop);
      expect(await match(restarted), isA<Unresolved>());

      backend.server.missingTables.clear();
      await restarted.pull();
      expect(await match(restarted), isA<Matched>());
    },
  );

  test(
    'gubitak članstva između tabela odbacuje upravo preuzete kućne redove',
    () async {
      serverFood('f-shared');
      serverAlias('a-shared', 'f-shared');
      serverFood('f-own', household: hid);
      serverAlias('a-own', 'f-own', household: hid);
      backend.server.beforeFetch = (table) {
        if (table == 'food_aliases') {
          backend.server.households.remove(scope.userId);
        }
      };

      final result = await downloader().run();
      expect(result.catalog, CatalogStatus.accessDenied);
      expect(await localFoods(), {'f-shared'});
      expect(await localAliases(), {'a-shared'});
      expect(await catalogCursors(), isEmpty);
    },
  );

  test('deljeni katalog vide svi, kućni samo domaćinstvo', () async {
    serverFood('f-shared');
    serverAlias('a-shared', 'f-shared');
    serverFood('f-own', household: hid);
    serverAlias('a-own', 'f-shared', household: hid);
    serverFood('f-other', household: 'home-drugo');
    serverAlias('a-other', 'f-other', household: 'home-drugo');

    final result = await downloader().run();
    expect(result.catalog, CatalogStatus.available);
    expect(await localFoods(), {'f-shared', 'f-own'});
    expect(await localAliases(), {'a-shared', 'a-own'});
  });

  test('server bez kataloga: ostalo se preuzima, status notOnServer', () async {
    backend.server.missingTables.addAll({'foods', 'food_aliases'});
    backend.server.upsert('pantry_items', [
      {
        'id': 'o1',
        'household_id': hid,
        'name': 'brašno',
        'quantity': 1000,
        'unit': 'g',
        'category': 'ostalo',
        'added_at': '2026-11-01T10:00:00.000Z',
      },
    ], 'id');

    final result = await downloader().run();
    expect(result.catalog, CatalogStatus.notOnServer);
    expect(result.deferred, 0);
    expect((await db.select(db.pantryItems).get()).single.id, 'o1');
    expect(await localFoods(), isEmpty);
    expect(await catalogCursors(), isEmpty);
  });

  test(
    'samo tabela aliasa nedostaje: namirnice ostaju, status notOnServer',
    () async {
      serverFood('f-shared');
      backend.server.missingTables.add('food_aliases');

      final result = await downloader().run();
      expect(result.catalog, CatalogStatus.notOnServer);
      expect(await localFoods(), {'f-shared'});
      expect(await localAliases(), isEmpty);
    },
  );

  test(
    'odbijen pristup briše kućne redove i poziciju, deljeni ostaju',
    () async {
      serverFood('f-shared');
      serverAlias('a-shared', 'f-shared');
      serverFood('f-own', household: hid);
      serverAlias('a-own', 'f-own', household: hid);
      await downloader().run();
      expect(await localFoods(), {'f-shared', 'f-own'});

      backend.server.deniedTables.add('foods');
      final denied = await downloader().run();
      expect(denied.catalog, CatalogStatus.accessDenied);
      expect(await localFoods(), {'f-shared'});
      expect(await localAliases(), {'a-shared'});
      expect(await catalogCursors(), isEmpty);

      backend.server.deniedTables.clear();
      final again = await downloader().run();
      expect(again.catalog, CatalogStatus.available);
      expect(await localFoods(), {'f-shared', 'f-own'});
      expect(await localAliases(), {'a-shared', 'a-own'});
    },
  );

  test(
    'trag brisanja kataloga radi i kad preuzimanje kataloga ne uspe',
    () async {
      serverFood('f-own', household: hid);
      serverAlias('a-own', 'f-own', household: hid);
      await downloader().run();
      expect(await localAliases(), {'a-own'});

      backend.server.delete('food_aliases', ['a-own'], 'id');
      backend.server.missingTables.add('foods');
      await downloader().run();
      expect(await localAliases(), isEmpty);
    },
  );

  test(
    'trag brisanja kućne namirnice briše namirnicu i njene aliase',
    () async {
      serverFood('f-own', household: hid);
      serverAlias('a-own', 'f-own', household: hid);
      await downloader().run();
      expect(await localFoods(), {'f-own'});

      backend.server.delete('foods', ['f-own'], 'id');
      await downloader().run();
      expect(await localFoods(), isEmpty);
      expect(await localAliases(), isEmpty);
    },
  );

  test(
    'bez mreže tokom kataloga baca TransientSyncError kao i do sada',
    () async {
      serverFood('f-shared');
      // Profil i svaki prazan entitet su po jedno preuzimanje; sledeće je katalog.
      backend.server.fetchesBeforeFailure = 1 + syncEntities.length;
      await expectLater(downloader().run(), throwsA(isA<TransientSyncError>()));
      expect(await localFoods(), isEmpty);
    },
  );

  test('povučena deljena namirnica zamenjuje keširan red', () async {
    serverFood('f-shared');
    await downloader().run();
    expect((await db.select(db.foods).getSingle()).withdrawnAt, isNull);

    serverFood('f-shared', withdrawnAt: '2026-11-02T10:00:00.000Z');
    await downloader().run();
    expect((await db.select(db.foods).getSingle()).withdrawnAt, isNotNull);
  });
  test('ispravka deljenog aliasa: zamena pre povlačenja istog ključa se prima '
      'u istom preuzimanju', () async {
    serverFood('f-old');
    serverFood('f-new');
    backend.server.upsert('food_aliases', [
      {
        'id': 'b-old',
        'food_id': 'f-old',
        'household_id': null,
        'alias': 'jaja',
        'alias_normalized': 'jaja',
        'withdrawn_at': null,
        'created_at': '2026-11-01T10:00:00.000Z',
      },
    ], 'id');
    await downloader().run();

    // Zamena stiže ispred povlačenja (isti ključ, raniji red preuzimanja).
    backend.server.upsert('food_aliases', [
      {
        'id': 'a-new',
        'food_id': 'f-new',
        'household_id': null,
        'alias': 'jaja',
        'alias_normalized': 'jaja',
        'withdrawn_at': null,
        'created_at': '2026-11-02T10:00:00.000Z',
      },
    ], 'id');
    backend.server.upsert('food_aliases', [
      {
        ...backend.server.table('food_aliases')['b-old']!,
        'withdrawn_at': '2026-11-02T10:00:00.000Z',
      },
    ], 'id');

    final result = await downloader().run();
    expect(result.deferred, 0);
    final rows = {
      for (final r in await db.select(db.foodAliases).get()) r.id: r,
    };
    expect(rows['a-new'], isNotNull);
    expect(rows['b-old']!.withdrawnAt, isNotNull);
  });

  test('gubitak članstva bez greške servera briše kućne redove, deljeni '
      'ostaju', () async {
    serverFood('f-shared');
    serverFood('f-own', household: hid);
    serverAlias('a-own', 'f-own', household: hid);
    await downloader().run();
    expect(await localFoods(), {'f-shared', 'f-own'});

    // RLS samo sakrije kućne redove; nijedan zahtev ne vrati grešku.
    backend.server.households.remove(scope.userId);
    final result = await downloader().run();
    expect(result.catalog, CatalogStatus.accessDenied);
    expect(await localFoods(), {'f-shared'});
    expect(await localAliases(), isEmpty);
    expect(await catalogCursors(), isEmpty);
  });

  test('ispravka deljenog aliasa: zamena i povlačenje na različitim stranicama '
      'se primaju u istom preuzimanju', () async {
    serverFood('f-old');
    serverFood('f-new');
    Map<String, Object?> shared(
      String id,
      String foodId, {
      String? withdrawn,
    }) => {
      'id': id,
      'food_id': foodId,
      'household_id': null,
      'alias': 'jaja',
      'alias_normalized': 'jaja',
      'withdrawn_at': withdrawn,
      'created_at': '2026-11-01T10:00:00.000Z',
    };
    backend.server.upsert('food_aliases', [shared('b-old', 'f-old')], 'id');
    await Downloader(
      db: db,
      remote: backend.sync,
      scope: scope,
      pageSize: 1,
    ).run();

    backend.server.upsert('food_aliases', [shared('a-new', 'f-new')], 'id');
    backend.server.upsert('food_aliases', [
      shared('b-old', 'f-old', withdrawn: '2026-11-02T10:00:00.000Z'),
    ], 'id');

    final result = await Downloader(
      db: db,
      remote: backend.sync,
      scope: scope,
      pageSize: 1,
    ).run();
    expect(result.deferred, 0);
    final rows = {
      for (final r in await db.select(db.foodAliases).get()) r.id: r,
    };
    expect(rows['a-new'], isNotNull);
    expect(rows['b-old']!.withdrawnAt, isNotNull);
  });
}
