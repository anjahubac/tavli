import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026);

  Future<void> addRecipe(String id, String household) => db
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
          householdId: Value(household),
        ),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await addRecipe('recipe', 'home');
    await addRecipe('second-recipe', 'home');
    await addRecipe('foreign', 'away');
  });
  tearDown(() => db.close());

  FavoriteRepository repository(String user, {String household = 'home'}) =>
      FavoriteRepository(
        db,
        scope: AccountScope(userId: user, householdId: household),
        writer: SyncedWriter(db, accountId: user),
      );

  Future<Set<String>> queuedIds() async => {
    for (final row in await db.select(db.syncOutbox).get()) row.recordId,
  };

  test('favorites are private and safe to toggle repeatedly', () async {
    final first = repository('first');
    final second = repository('second');

    await first.setFavorite('recipe', isFavorite: true);
    await first.setFavorite('recipe', isFavorite: true);
    expect(await first.watchFavoriteRecipeIds().first, {'recipe'});
    expect(await second.getFavoriteRecipeIds(), isEmpty);
    expect(await queuedIds(), {'first:recipe'});
    await expectLater(
      first.setFavorite('foreign', isFavorite: true),
      throwsA(isA<Unavailable>()),
    );

    await first.setFavorite('recipe', isFavorite: false);
    expect(await first.getFavoriteRecipeIds(), isEmpty);
    expect((await db.select(db.userFavorites).getSingle()).isFavorite, isFalse);
    await first.setFavorite('recipe', isFavorite: true);
    await second.setFavorite('recipe', isFavorite: true);
    expect(await second.getFavoriteRecipeIds(), {'recipe'});

    await const RecipeEntity().deleteLocal(db, 'recipe');
    expect(await first.getFavoriteRecipeIds(), isEmpty);
    expect(await db.select(db.userFavorites).get(), isEmpty);
  });

  test('favorites on left-behind recipes are dropped after a household '
      'change, and the first new favorite is kept', () async {
    final atHome = repository('first');
    await atHome.setFavorite('recipe', isFavorite: true);
    await atHome.setFavorite('second-recipe', isFavorite: true);
    // A peer's favorite and queued write stay untouched.
    await repository('peer').setFavorite('recipe', isFavorite: true);

    // The user joined "away" and left the "home" recipes behind.
    final away = repository('first', household: 'away');
    expect(await away.getFavoriteRecipeIds(), isEmpty);
    await away.dropStaleFavorites();
    expect((await db.select(db.userFavorites).get()).map((row) => row.userId), [
      'peer',
    ]);
    expect(await queuedIds(), {'peer:recipe'});

    await away.setFavorite('foreign', isFavorite: true);
    await away.dropStaleFavorites();
    expect(await away.getFavoriteRecipeIds(), {'foreign'});
    expect(await queuedIds(), {'peer:recipe', 'first:foreign'});
  });

  test('a recipe brought to the new household keeps its favorite', () async {
    // The join copies the recipe and the favorite under the new household.
    await addRecipe('brought', 'away');
    await const FavoriteEntity().write(db, {
      'id': FavoriteRepository.idFor('first', 'brought'),
      'user_id': 'first',
      'recipe_id': 'brought',
      'recipe_household_id': 'away',
      'is_favorite': true,
    });

    final away = repository('first', household: 'away');
    await away.dropStaleFavorites();
    expect(await away.getFavoriteRecipeIds(), {'brought'});
  });
}
