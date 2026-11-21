import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/account_api.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/sync/downloader.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli/sync/uploader.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_photo_store.dart';

void main() {
  for (final aFirst in [true, false]) {
    test(
      'favorite edits converge and stale edits are cleaned (A first: $aFirst)',
      () async {
        final backend = FakeBackend();
        const email = 'favorite-sync@example.test';
        final session = await backend.auth.verifyCode(email, FakeServer.code);
        final userId = session.userId;
        final householdId = backend.server.households[userId]!;
        final scope = AccountScope(userId: userId, householdId: householdId);
        final accountApi = _MembershipApi(backend, scope);
        final now = DateTime.utc(2026, 11);
        final previousWarning =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(() {
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
        });
        final a = AppDatabase(NativeDatabase.memory());
        final b = AppDatabase(NativeDatabase.memory());
        addTearDown(a.close);
        addTearDown(b.close);
        const recipeIds = ['first', 'second'];
        backend.server.upsert('recipes', [
          for (final id in recipeIds)
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

        SyncedWriter writer(AppDatabase db) =>
            SyncedWriter(db, accountId: userId);
        FavoriteRepository favorites(AppDatabase db) => FavoriteRepository(
          db,
          scope: scope,
          writer: writer(db),
          accountApi: accountApi,
        );
        Uploader uploader(AppDatabase db) => Uploader(
          db: db,
          scope: scope,
          remote: backend.sync,
          photos: backend.photos,
          photoStore: FakePhotoStore(),
          refreshSession: () async => true,
          beforeFavoriteUpload: favorites(db).reconcileMembership,
        );
        for (final db in [a, b]) {
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  userId: userId,
                  email: email,
                  householdId: householdId,
                  householdName: 'Test',
                  role: 'owner',
                  createdAt: now,
                  favoriteMembershipId: Value(accountApi.id),
                ),
              );
          await Downloader(db: db, scope: scope, remote: backend.sync).run();
        }

        backend.server.offline = true;
        await favorites(a).setFavorite('first', isFavorite: true);
        await favorites(b).setFavorite('second', isFavorite: true);
        expect((await uploader(a).run()).offline, isTrue);
        backend.server.offline = false;
        final sendOrder = aFirst ? [a, b] : [b, a];
        for (final db in sendOrder) {
          expect((await uploader(db).run()).sent, 1);
        }
        const entity = FavoriteEntity();
        await writer(a).upsert(entity.name, '${accountApi.id}:first');
        expect((await uploader(a).run()).sent, 1);
        expect(backend.server.rows(entity.remoteTable), hasLength(2));
        for (final db in sendOrder) {
          await Downloader(db: db, scope: scope, remote: backend.sync).run();
          expect(await favorites(db).getFavoriteRecipeIds(), recipeIds.toSet());
        }

        await favorites(a).setFavorite('first', isFavorite: false);
        accountApi.id = 'new-membership';
        backend.server.calls.clear();
        expect((await uploader(a).run()).sent, 0);
        expect(await favorites(a).getFavoriteRecipeIds(), isEmpty);
        expect(await a.select(a.syncOutbox).get(), isEmpty);
        expect(
          backend.server.calls,
          isNot(contains('upsert:${entity.remoteTable}:1')),
        );
        await favorites(a).setFavorite('first', isFavorite: true);
        expect((await uploader(a).run()).sent, 1);
        expect(
          backend.server.rows(entity.remoteTable).last['membership_id'],
          accountApi.id,
        );
      },
    );
  }
}

class _MembershipApi implements AccountApi {
  _MembershipApi(this.backend, this.scope);

  final FakeBackend backend;
  final AccountScope scope;
  String id = 'old-membership';

  @override
  Future<RemoteAccount> fetch() async {
    if (backend.server.offline) throw const Offline();
    return RemoteAccount(
      userId: scope.userId,
      email: 'favorite-sync@example.test',
      householdId: scope.householdId,
      householdName: 'Test',
      role: 'owner',
      favoriteMembershipId: id,
    );
  }

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}
