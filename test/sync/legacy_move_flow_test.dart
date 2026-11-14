import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show SnackBar;
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/account/sync_banner.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/legacy_mover.dart';
import 'package:tavli/sync/photo_sync.dart';
import 'package:tavli/sync/sync_engine.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';
import '../helpers/fake_timers.dart';
import '../helpers/test_app.dart';
import '../helpers/v3_schema.dart';

/// Baza verzije 3 (pre naloga): 3 recepta (jedan sa slikom, verzije) i
/// lista sa 2 stavke.
NativeDatabase v3Database() => NativeDatabase.memory(
  setup: (raw) {
    for (final s in v3Schema) {
      raw.execute(s);
    }
    raw.execute(
      "INSERT INTO recipes VALUES ('r1', 'Sarma', 4, 60, 'manual', '[]', "
      "'[]', 'recipe_photos/a.jpg', NULL, 1, 2)",
    );
    raw.execute(
      "INSERT INTO recipes VALUES ('r2', 'Pasulj', 2, NULL, 'ai', '[]', "
      "'[]', NULL, NULL, 1, 2)",
    );
    raw.execute(
      "INSERT INTO recipes VALUES ('r3', 'Musaka', 6, NULL, 'manual', '[]', "
      "'[]', NULL, NULL, 1, 2)",
    );
    for (final r in ['r1', 'r1', 'r2']) {
      raw.execute(
        'INSERT INTO recipe_versions (recipe_id, recipe_json, change_kind, '
        "created_at) VALUES ('$r', '{}', 'manual', 1)",
      );
    }
    raw.execute(
      "INSERT INTO shopping_lists VALUES ('l1', 'Lista', NULL, NULL, 1)",
    );
    raw.execute(
      'INSERT INTO shopping_items (list_id, name, category) '
      "VALUES ('l1', 'mleko', 'ostalo'), ('l1', 'hleb', 'pekara')",
    );
    raw.execute('PRAGMA user_version = 3');
  },
);

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late FakePhotoStore photos;
  late AccountScope scope;

  setUp(() async {
    db = AppDatabase(v3Database());
    backend = FakeBackend();
    photos = FakePhotoStore()
      ..saved['recipe_photos/a.jpg'] = Uint8List.fromList([1, 2, 3]);
    final s = await backend.auth.verifyCode('ana@mail.com', FakeServer.code);
    scope = AccountScope(
      userId: s.userId,
      householdId: backend.server.households[s.userId]!,
    );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            userId: scope.userId,
            email: 'ana@mail.com',
            householdId: scope.householdId,
            householdName: 'Moje domaćinstvo',
            role: 'owner',
            createdAt: DateTime.utc(2026),
          ),
        );
  });
  tearDown(() => db.close());

  /// Jedna "prijava" na uređaju: nov engine i pokretanje.
  Future<List<int>> signInOnce() async {
    final timers = FakeTimers();
    final engine = SyncEngine(
      db: db,
      scope: scope,
      uploader: Uploader(
        db: db,
        remote: backend.sync,
        photos: backend.photos,
        photoStore: photos,
        scope: scope,
        refreshSession: () async => true,
      ),
      downloader: Downloader(db: db, remote: backend.sync, scope: scope),
      photoSync: PhotoSync(
        db: db,
        remote: backend.photos,
        store: photos,
        scope: scope,
      ),
      legacyMover: LegacyMover(db),
      timer: timers.call,
    );
    final moved = <int>[];
    final sub = engine.movedSaved.listen(moved.add);
    await engine.onStart();
    await pumpQueue();
    await sub.cancel();
    engine.stop();
    return moved;
  }

  Future<(int, int, int)> deviceCounts() async => (
    (await db.select(db.recipes).get()).length,
    (await db.select(db.recipeVersions).get()).length,
    (await db.select(db.shoppingItems).get()).length,
  );

  (int, int, int) serverCounts() => (
    backend.server.table('recipes').length,
    backend.server.table('recipe_versions').length,
    backend.server.table('shopping_items').length,
  );

  test('stari podaci: 3 recepta i 2 stavke na uređaju i serveru, '
      'i posle 3 odjave/prijave', () async {
    final moved = await signInOnce();
    expect(moved.single, 9); // 3 recepta, 3 verzije, lista, 2 stavke
    expect(await deviceCounts(), (3, 3, 2));
    expect(serverCounts(), (3, 3, 2));
    expect(backend.server.photos.keys, ['${scope.householdId}/a.jpg']);
    expect(
      (await db.select(db.recipes).get()).every(
        (r) => r.householdId == scope.householdId,
      ),
      isTrue,
    );
    expect(await db.select(db.syncOutbox).get(), isEmpty);

    for (var i = 0; i < 3; i++) {
      expect(await signInOnce(), isEmpty);
      expect(await deviceCounts(), (3, 3, 2));
      expect(serverCounts(), (3, 3, 2));
    }
  });

  test('nalog već ima 2 recepta na serveru: posle prebacivanja 5', () async {
    for (final id in ['s1', 's2']) {
      backend.server.upsert('recipes', [
        {
          'id': id,
          'household_id': scope.householdId,
          'title': 'Sa servera $id',
          'servings': 2,
          'source': 'manual',
          'ingredients': <Object>[],
          'steps': <Object>[],
          'created_at': '2026-10-30T10:00:00.000Z',
        },
      ], 'id');
    }
    await signInOnce();
    expect((await deviceCounts()).$1, 5);
    expect(serverCounts().$1, 5);
    final titles = [for (final r in await db.select(db.recipes).get()) r.title];
    expect(titles, containsAll(['Sarma', 'Sa servera s1']));
  });

  testTavli('poruka kad prebačeni podaci stignu na server', (tester) async {
    await pumpTavli(
      tester,
      setup: (db) => db
          .into(db.recipes)
          .insert(
            RecipesCompanion.insert(
              id: 'stari',
              title: 'Stari recept',
              servings: 1,
              source: 'manual',
              ingredientsJson: '[]',
              stepsJson: '[]',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
    );
    await tester.pumpAndSettle();
    expect(find.text(dataMovedText), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Stari recept'), findsOneWidget);
  });

  testTavli('bez starih podataka nema poruke', (tester) async {
    await pumpTavli(tester);
    await tester.pumpAndSettle();
    expect(find.text(dataMovedText), findsNothing);
  });
}
