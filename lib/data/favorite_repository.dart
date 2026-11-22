import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../account/auth_gateway.dart';
import '../sync/entities.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Private favorites of the active user. A favorite follows its recipe: it is
/// visible only while the recipe is in the active household.
class FavoriteRepository {
  FavoriteRepository(
    this._db, {
    required AccountScope scope,
    required SyncedWriter writer,
  }) : _scope = scope,
       _writer = writer {
    if (scope.userId.isEmpty || writer.accountId != scope.userId) {
      throw ArgumentError('Omiljeni recepti moraju pripadati aktivnom nalogu.');
    }
  }

  static const _entity = FavoriteEntity();

  final AppDatabase _db;
  final AccountScope _scope;
  final SyncedWriter _writer;

  /// One row per user and recipe, so offline devices converge on the same ID.
  static String idFor(String userId, String recipeId) => '$userId:$recipeId';

  Stream<Set<String>> watchFavoriteRecipeIds() =>
      _favorites().watch().map(_recipeIds);

  Future<Set<String>> getFavoriteRecipeIds() async =>
      _recipeIds(await _favorites().get());

  Future<void> setFavorite(String recipeId, {required bool isFavorite}) async {
    if (recipeId.isEmpty || recipeId.length > 64) {
      throw ArgumentError('Identifikator recepta nije ispravan.');
    }
    await _db.transaction(() async {
      final recipe =
          await (_db.select(_db.recipes)..where(
                (row) =>
                    row.id.equals(recipeId) &
                    row.householdId.equals(_scope.householdId),
              ))
              .getSingleOrNull();
      if (recipe == null) throw const Unavailable();
      final id = idFor(_scope.userId, recipeId);
      final existing = await _entity.read(_db, id);
      if ((existing?.isFavorite ?? false) == isFavorite) return;
      await _db
          .into(_db.userFavorites)
          .insertOnConflictUpdate(
            UserFavoritesCompanion.insert(
              id: id,
              userId: _scope.userId,
              recipeId: recipeId,
              recipeHouseholdId: _scope.householdId,
              isFavorite: isFavorite,
            ),
          );
      await _writer.upsert(_entity.name, id);
    });
  }

  /// Drops cached favorites and queued favorite writes for recipes outside the
  /// active household (left behind or deleted). The server would reject them
  /// anyway; removing them locally keeps the queue from getting stuck.
  Future<void> dropStaleFavorites() => _db.transaction(() async {
    final current = _db.selectOnly(_db.userFavorites)
      ..addColumns([_db.userFavorites.id])
      ..join([
        innerJoin(
          _db.recipes,
          _db.recipes.id.equalsExp(_db.userFavorites.recipeId),
          useColumns: false,
        ),
      ])
      ..where(
        _db.userFavorites.userId.equals(_scope.userId) &
            _db.userFavorites.recipeHouseholdId.equals(_scope.householdId) &
            _db.recipes.householdId.equals(_scope.householdId),
      );
    await (_db.delete(_db.syncOutbox)..where(
          (row) =>
              row.accountId.equals(_scope.userId) &
              row.entity.equals(_entity.name) &
              row.recordId.isInQuery(current).not(),
        ))
        .go();
    await (_db.delete(_db.userFavorites)..where(
          (row) =>
              row.userId.equals(_scope.userId) &
              row.id.isInQuery(current).not(),
        ))
        .go();
  });

  JoinedSelectStatement<HasResultSet, Object?> _favorites() {
    final favorite = _db.userFavorites;
    final recipe = _db.recipes;
    return _db.select(favorite).join([
      innerJoin(
        recipe,
        recipe.id.equalsExp(favorite.recipeId),
        useColumns: false,
      ),
    ])..where(
      favorite.userId.equals(_scope.userId) &
          favorite.recipeHouseholdId.equals(_scope.householdId) &
          recipe.householdId.equals(_scope.householdId) &
          favorite.isFavorite.equals(true),
    );
  }

  Set<String> _recipeIds(List<TypedResult> rows) => Set.unmodifiable({
    for (final row in rows) row.readTable(_db.userFavorites).recipeId,
  });
}
