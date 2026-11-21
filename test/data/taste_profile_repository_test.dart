import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/taste_profile_repository.dart';
import 'package:tavli/domain/dish_kind_preferences.dart';
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
