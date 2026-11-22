import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';

void main() {
  const entity = FavoriteEntity();
  const email = 'favorite-sync@example.test';
  final now = DateTime.utc(2026, 11);

  late FakeBackend backend;
  late String userId;

  setUp(() async {
    backend = FakeBackend();
    userId = (await backend.auth.verifyCode(email, FakeServer.code)).userId;
    final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
    });
  });

  void addServerRecipes(String householdId, List<String> ids) =>
      backend.server.upsert('recipes', [
        for (final id in ids)
          {
            'id': id,
            'household_id': householdId,
            'title': id,
            'servings': 1,
            'source': 'manual',
            'ingredients': <Object>[],
            'steps': <Object>[],
            'created_at': now.toIso8601String(),
          },
      ], 'id');

  Future<AppDatabase> device(AccountScope scope) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            userId: userId,
            email: email,
            householdId: scope.householdId,
            householdName: 'Test',
            role: 'owner',
            createdAt: now,
          ),
        );
    return db;
  }

  FavoriteRepository favorites(AppDatabase db, AccountScope scope) =>
      FavoriteRepository(
        db,
        scope: scope,
        writer: SyncedWriter(db, accountId: userId),
      );

  Uploader uploader(AppDatabase db, AccountScope scope) => Uploader(
    db: db,
    scope: scope,
    remote: backend.sync,
    photos: backend.photos,
    photoStore: FakePhotoStore(),
    refreshSession: () async => true,
    beforeFavoriteUpload: favorites(db, scope).dropStaleFavorites,
  );

  Future<void> pull(AppDatabase db, AccountScope scope) =>
      Downloader(db: db, scope: scope, remote: backend.sync).run();

  for (final aFirst in [true, false]) {
    test(
      'offline favorites from two devices converge (A first: $aFirst)',
      () async {
        final householdId = backend.server.households[userId]!;
        final scope = AccountScope(userId: userId, householdId: householdId);
        const recipeIds = ['first', 'second'];
        addServerRecipes(householdId, recipeIds);
        final a = await device(scope);
        final b = await device(scope);
        for (final db in [a, b]) {
          await pull(db, scope);
        }

        backend.server.offline = true;
        await favorites(a, scope).setFavorite('first', isFavorite: true);
        await favorites(b, scope).setFavorite('second', isFavorite: true);
        expect((await uploader(a, scope).run()).offline, isTrue);
        backend.server.offline = false;
        final sendOrder = aFirst ? [a, b] : [b, a];
        for (final db in sendOrder) {
          expect((await uploader(db, scope).run()).sent, 1);
        }
        expect(backend.server.rows(entity.remoteTable), hasLength(2));
        for (final db in sendOrder) {
          await pull(db, scope);
          expect(
            await favorites(db, scope).getFavoriteRecipeIds(),
            recipeIds.toSet(),
          );
        }
        expect(
          backend.server.rows(entity.remoteTable).map((row) => row['id']),
          unorderedEquals(['$userId:first', '$userId:second']),
        );
      },
    );
  }

  test('after joining another household, a left-behind favorite is not sent '
      'and the first new favorite reaches the server', () async {
    final home = backend.server.households[userId]!;
    final homeScope = AccountScope(userId: userId, householdId: home);
    addServerRecipes(home, ['left-behind']);
    final db = await device(homeScope);
    await pull(db, homeScope);

    backend.server.offline = true;
    await favorites(db, homeScope).setFavorite('left-behind', isFavorite: true);
    backend.server.offline = false;

    // The join is confirmed on the server; the device now uses the new scope.
    const away = 'away-household';
    backend.server.households[userId] = away;
    addServerRecipes(away, ['destination']);
    final awayScope = AccountScope(userId: userId, householdId: away);
    await (db.update(db.accounts)..where((row) => row.userId.equals(userId)))
        .write(const AccountsCompanion(householdId: Value(away)));
    await pull(db, awayScope);

    await favorites(db, awayScope).setFavorite('destination', isFavorite: true);
    backend.server.calls.clear();
    expect((await uploader(db, awayScope).run()).sent, 1);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
    expect(backend.server.rows(entity.remoteTable).single, {
      ...backend.server.rows(entity.remoteTable).single,
      'id': '$userId:destination',
      'recipe_household_id': away,
      'is_favorite': true,
    });
    expect(await favorites(db, awayScope).getFavoriteRecipeIds(), {
      'destination',
    });
  });
}
