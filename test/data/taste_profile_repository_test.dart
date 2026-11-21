import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/taste_profile_repository.dart';
import 'package:tavli/domain/dish_kind_preferences.dart';
import 'package:tavli/domain/food_preferences.dart';
import 'package:tavli/domain/recipe_labels.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  late AppDatabase db;

  TasteProfileRepository repository(String userId) => TasteProfileRepository(
    db,
    scope: AccountScope(userId: userId, householdId: 'household'),
    writer: SyncedWriter(db, accountId: userId),
  );

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'preserves legacy fields and syncs canonical dish-kind values',
    () async {
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: 'member',
              profileJson:
                  '{"ljuto":true,"likedDishKinds":["old_kind","pasta"]}',
            ),
          );
      final repo = repository('member');
      expect((await repo.getDishPreferences()).liked, {DishKind.pasta});

      await repo.saveDishPreferences(
        DishKindPreferences(
          liked: {DishKind.salad, DishKind.bakedFried},
          disliked: {DishKind.salad},
        ),
      );

      final stored = await db.select(db.userProfiles).getSingle();
      expect(const TasteProfileEntity().toRemote(stored), {
        'user_id': 'member',
        'profile': {
          'ljuto': true,
          'likedDishKinds': ['baked_fried'],
          'dislikedDishKinds': ['salad'],
        },
      });
      expect(
        await repo.getDishPreferences(),
        DishKindPreferences(
          liked: {DishKind.bakedFried},
          disliked: {DishKind.salad},
        ),
      );

      final operation = await db.select(db.syncOutbox).getSingle();
      expect(operation.accountId, 'member');
      expect(operation.recordId, 'member');
      expect(operation.entity, 'taste_profile');
      expect(operation.op, OutboxOp.upsert);
    },
  );

  test('saves catalog food preferences independently of dish kinds', () async {
    const first = '46d60c83-0d05-466e-9c28-585a8be28d8f';
    const second = 'e760678c-1bce-4cde-8bca-b763885c7895';
    final repo = repository('member');
    expect((await repo.getFoodPreferences()).liked, isEmpty);
    expect(
      () => FoodPreferences(liked: {'arbitrary food name'}),
      throwsArgumentError,
    );

    await repo.saveDishPreferences(
      DishKindPreferences(liked: {DishKind.pasta}),
    );
    await repo.saveFoodPreferences(
      FoodPreferences(liked: {first, second}, disliked: {first}),
    );
    final stored = await db.select(db.userProfiles).getSingle();
    expect(const TasteProfileEntity().toRemote(stored)['profile'], {
      'likedDishKinds': ['pasta'],
      'dislikedDishKinds': <String>[],
      'likedFoodIds': [second],
      'dislikedFoodIds': [first],
    });
    final food = await repo.watchFoodPreferences().first;
    expect(food.liked, {second});
    expect(food.disliked, {first});
    expect((await repo.getDishPreferences()).liked, {DishKind.pasta});
    expect((await repository('other').getFoodPreferences()).liked, isEmpty);
    expect(await db.select(db.syncOutbox).get(), hasLength(1));
  });

  test('keeps preferences private across accounts in one household', () async {
    final first = repository('first');
    final second = repository('second');
    await first.saveDishPreferences(
      DishKindPreferences(liked: {DishKind.pasta}),
    );

    expect((await second.getDishPreferences()).liked, isEmpty);
    await second.saveDishPreferences(
      DishKindPreferences(disliked: {DishKind.pasta}),
    );
    expect((await first.getDishPreferences()).liked, {DishKind.pasta});
    expect((await first.getDishPreferences()).disliked, isEmpty);
    expect((await second.getDishPreferences()).disliked, {DishKind.pasta});

    await first.saveDishPreferences(DishKindPreferences());
    expect((await first.getDishPreferences()).liked, isEmpty);
    expect(await db.select(db.syncOutbox).get(), hasLength(2));
  });

  test('rejects a repository whose scope and writer accounts differ', () {
    expect(() => repository(''), throwsArgumentError);
    expect(
      () => TasteProfileRepository(
        db,
        scope: const AccountScope(userId: 'first', householdId: 'household'),
        writer: SyncedWriter(db, accountId: 'second'),
      ),
      throwsArgumentError,
    );
  });

  test('rejects malformed profile JSON without changing the row', () async {
    await db
        .into(db.userProfiles)
        .insert(UserProfilesCompanion.insert(id: 'member', profileJson: '[]'));
    final repo = repository('member');

    await expectLater(
      repo.saveDishPreferences(DishKindPreferences()),
      throwsFormatException,
    );

    expect((await db.select(db.userProfiles).getSingle()).profileJson, '[]');
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });
}
