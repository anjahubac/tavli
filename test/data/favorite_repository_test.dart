import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/account_api.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  test(
    'favorites are private, membership-bound and safe to toggle repeatedly',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026);
      for (final user in ['first', 'second']) {
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                userId: user,
                email: '$user@example.test',
                householdId: 'home',
                householdName: 'Home',
                role: 'owner',
                createdAt: now,
                favoriteMembershipId: Value('membership-$user'),
              ),
            );
      }
      for (final (id, home) in [('recipe', 'home'), ('foreign', 'away')]) {
        await db
            .into(db.recipes)
            .insert(
              RecipesCompanion.insert(
                id: id,
                title: 'Recipe',
                servings: 1,
                source: 'manual',
                ingredientsJson: '[]',
                stepsJson: '[]',
                createdAt: now,
                updatedAt: now,
                householdId: Value(home),
              ),
            );
      }
      final accountApi = _AccountApi();
      FavoriteRepository repository(String user) => FavoriteRepository(
        db,
        scope: AccountScope(userId: user, householdId: 'home'),
        writer: SyncedWriter(db, accountId: user),
        accountApi: accountApi,
      );
      final first = repository('first');
      final second = repository('second');

      await first.setFavorite('recipe', isFavorite: true);
      await first.setFavorite('recipe', isFavorite: true);
      expect(await first.watchFavoriteRecipeIds().first, {'recipe'});
      expect(await second.getFavoriteRecipeIds(), isEmpty);
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
      await expectLater(
        first.setFavorite('foreign', isFavorite: true),
        throwsA(isA<Unavailable>()),
      );

      await first.setFavorite('recipe', isFavorite: false);
      expect(await first.getFavoriteRecipeIds(), isEmpty);
      expect(
        (await db.select(db.userFavorites).getSingle()).isFavorite,
        isFalse,
      );
      await first.setFavorite('recipe', isFavorite: true);

      expect(await first.refreshMembership(), 'new-membership');
      expect(await first.getFavoriteRecipeIds(), isEmpty);
      await first.setFavorite('recipe', isFavorite: true);
      expect(await first.getFavoriteRecipeIds(), {'recipe'});
      final queued = await db.select(db.syncOutbox).get();
      expect(queued.map((operation) => operation.recordId).toSet(), {
        'membership-first:recipe',
        'new-membership:recipe',
      });
      await const RecipeEntity().deleteLocal(db, 'recipe');
      expect(await first.getFavoriteRecipeIds(), isEmpty);
      expect(await db.select(db.userFavorites).get(), isEmpty);
    },
  );
}

class _AccountApi implements AccountApi {
  @override
  Future<RemoteAccount> fetch() async => const RemoteAccount(
    userId: 'first',
    email: 'first@example.test',
    householdId: 'home',
    householdName: 'Home',
    role: 'owner',
    favoriteMembershipId: 'new-membership',
  );

  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}
