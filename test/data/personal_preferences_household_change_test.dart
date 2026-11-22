import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/allergen_repository.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/favorite_repository.dart';
import 'package:tavli/data/taste_profile_repository.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/domain/cuisine_preferences.dart';
import 'package:tavli/domain/dish_kind_preferences.dart';
import 'package:tavli/domain/food_preferences.dart';
import 'package:tavli/domain/recipe_labels.dart';
import 'package:tavli/sync/synced_writer.dart';

/// Preferences and allergens belong to the profile, so they survive a
/// household change on the same device.
void main() {
  const user = 'member';
  const home = AccountScope(userId: user, householdId: 'home');
  const away = AccountScope(userId: user, householdId: 'away');
  const foodId = '46d60c83-0d05-466e-9c28-585a8be28d8f';

  test('preferences and allergens stay after a household change', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final writer = SyncedWriter(db, accountId: user);
    TasteProfileRepository taste(AccountScope scope) =>
        TasteProfileRepository(db, scope: scope, writer: writer);
    AllergenRepository allergens(AccountScope scope) =>
        AllergenRepository(db, scope: scope, writer: writer);

    await taste(home).saveDishPreferences(
      DishKindPreferences(liked: {DishKind.soup}, disliked: {DishKind.salad}),
    );
    await taste(home).saveFoodPreferences(FoodPreferences(liked: {foodId}));
    await taste(
      home,
    ).saveCuisinePreferences(CuisinePreferences(disliked: {Cuisine.italian}));
    await allergens(home).saveSelection({AllergenGroup.milk});
    final queued = await db.select(db.syncOutbox).get();

    // The account moves to "away"; favorite cleanup runs for the new scope.
    await FavoriteRepository(
      db,
      scope: away,
      writer: writer,
    ).dropStaleFavorites();

    final dish = await taste(away).getDishPreferences();
    expect(dish.liked, {DishKind.soup});
    expect(dish.disliked, {DishKind.salad});
    expect((await taste(away).getFoodPreferences()).liked, {foodId});
    expect((await taste(away).getCuisinePreferences()).disliked, {
      Cuisine.italian,
    });
    expect(await allergens(away).getSelection(), {AllergenGroup.milk});
    // Unsent preference changes are still queued for the server.
    expect(
      (await db.select(db.syncOutbox).get()).map((row) => row.seq),
      queued.map((row) => row.seq),
    );
  });
}
