import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/recipe_rating_repository.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> summary(String household, String recipe, double avg, int n) => db
      .into(db.ratingSummaries)
      .insert(
        RatingSummariesCompanion.insert(
          householdId: household,
          recipeId: recipe,
          averageStars: avg,
          ratingCount: n,
        ),
      );

  RecipeRatingRepository repository() => RecipeRatingRepository(
    db,
    writer: SyncedWriter(db, accountId: 'u1'),
    scope: const AccountScope(userId: 'u1', householdId: 'home'),
  );

  test('watchHouseholdSummaries returns only the active household', () async {
    await summary('home', 'a', 4.5, 2);
    await summary('home', 'b', 3, 1);
    await summary('away', 'c', 5, 9);

    final map = await repository().watchHouseholdSummaries().first;

    expect(map.keys, {'a', 'b'});
    expect(map['a']!.averageStars, 4.5);
    expect(map['a']!.ratingCount, 2);
  });

  test('watchHouseholdSummaries is empty without ratings', () async {
    expect(await repository().watchHouseholdSummaries().first, isEmpty);
  });
}
