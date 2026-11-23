import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/ids.dart';
import '../domain/recipe_rating.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Private ratings and the household's aggregate rating cache.
class RecipeRatingRepository {
  RecipeRatingRepository(
    this._db, {
    required this._writer,
    required this._scope,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SyncedWriter _writer;
  final AccountScope _scope;
  final DateTime Function() _clock;

  SimpleSelectStatement<$RatingsTable, RatingRow> _myRating(String recipeId) =>
      _db.select(_db.ratings)..where(
        (t) => t.userId.equals(_scope.userId) & t.recipeId.equals(recipeId),
      );

  Stream<RecipeRating?> watchMyRating(String recipeId) =>
      _myRating(recipeId).watchSingleOrNull().map(_ratingFromRow);

  Future<RecipeRating?> getMyRating(String recipeId) =>
      _myRating(recipeId).getSingleOrNull().then(_ratingFromRow);

  Stream<RecipeRatingSummary?> watchHouseholdSummary(String recipeId) =>
      (_db.select(_db.ratingSummaries)..where(
            (t) =>
                t.householdId.equals(_scope.householdId) &
                t.recipeId.equals(recipeId),
          ))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : RecipeRatingSummary(
                    averageStars: row.averageStars,
                    ratingCount: row.ratingCount,
                  ),
          );

  /// All cached summaries of the active household, keyed by recipe id.
  Stream<Map<String, RecipeRatingSummary>> watchHouseholdSummaries() =>
      (_db.select(
        _db.ratingSummaries,
      )..where((t) => t.householdId.equals(_scope.householdId))).watch().map(
        (rows) => {
          for (final row in rows)
            row.recipeId: RecipeRatingSummary(
              averageStars: row.averageStars,
              ratingCount: row.ratingCount,
            ),
        },
      );

  /// Save or replace the current rating. A supplied [cookedAt] records the
  /// cooking action; editing the rating later leaves its original cook date.
  Future<void> save({
    required String recipeId,
    required int stars,
    String? personalNote,
    DateTime? cookedAt,
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError.value(stars, 'stars', 'Must be between 1 and 5');
    }
    await _db.transaction(() async {
      final recipe =
          await (_db.select(_db.recipes)..where(
                (t) =>
                    t.id.equals(recipeId) &
                    t.householdId.equals(_scope.householdId),
              ))
              .getSingleOrNull();
      if (recipe == null) throw StateError('Recipe does not exist');

      final current = await _myRating(recipeId).getSingleOrNull();
      if (current == null) {
        final id = newId();
        await _db
            .into(_db.ratings)
            .insert(
              RatingsCompanion.insert(
                id: id,
                recipeId: recipeId,
                stars: stars,
                isComfortFood: const Value(false),
                comment: Value(_cleanNote(personalNote)),
                cookedAt: cookedAt ?? _clock(),
                userId: Value(_scope.userId),
              ),
            );
        await _writer.upsert('rating', id);
        return;
      }

      await (_db.update(
        _db.ratings,
      )..where((t) => t.id.equals(current.id))).write(
        RatingsCompanion(
          stars: Value(stars),
          comment: personalNote == null
              ? const Value.absent()
              : Value(_cleanNote(personalNote)),
          cookedAt: cookedAt == null ? const Value.absent() : Value(cookedAt),
        ),
      );
      await _writer.upsert('rating', current.id);
    });
  }

  static String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static RecipeRating? _ratingFromRow(RatingRow? row) => row == null
      ? null
      : RecipeRating(
          recipeId: row.recipeId,
          stars: row.stars,
          cookedAt: row.cookedAt,
          personalNote: row.comment,
        );
}
