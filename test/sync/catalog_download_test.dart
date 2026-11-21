import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/sync_remote.dart';

import '../helpers/fake_backend.dart';

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
}
