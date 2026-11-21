import 'package:drift/drift.dart';

import '../account/account_api.dart';
import '../account/auth_controller.dart';
import '../account/auth_gateway.dart';
import '../sync/entities.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Favorites belong to the active user and the membership that granted access.
class FavoriteRepository {
  FavoriteRepository(
    this._db, {
    required AccountScope scope,
    required SyncedWriter writer,
    required this._accountApi,
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
  final AccountApi _accountApi;

  Stream<Set<String>> watchFavoriteRecipeIds() =>
      _favorites().watch().map(_recipeIds);

  Future<Set<String>> getFavoriteRecipeIds() async =>
      _recipeIds(await _favorites().get());

  Future<void> setFavorite(String recipeId, {required bool isFavorite}) async {
    if (recipeId.isEmpty || recipeId.length > 64) {
      throw ArgumentError('Identifikator recepta nije ispravan.');
    }
    final membershipId =
        await _cachedMembershipId() ?? await refreshMembership();
    await _db.transaction(() async {
      if (await _cachedMembershipId() != membershipId) {
        throw const Unavailable();
      }
      final recipe =
          await (_db.select(_db.recipes)..where(
                (row) =>
                    row.id.equals(recipeId) &
                    row.householdId.equals(_scope.householdId),
              ))
              .getSingleOrNull();
      if (recipe == null) throw const Unavailable();
      final id = '$membershipId:$recipeId';
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
              membershipId: membershipId,
              isFavorite: isFavorite,
            ),
          );
      await _writer.upsert(_entity.name, id);
    });
  }

  /// Refreshes the membership identity after access changes. Pending writes
  /// tied to an older identity are never reissued for the new membership.
  Future<String> refreshMembership() async {
    final remote = await _accountApi.fetch();
    if (remote.userId != _scope.userId ||
        remote.householdId != _scope.householdId) {
      throw const Unavailable();
    }
    final membershipId = remote.favoriteMembershipId;
    if (membershipId == null || membershipId.isEmpty) throw const Unavailable();
    final updated =
        await (_db.update(_db.accounts)..where(
              (row) =>
                  row.userId.equals(_scope.userId) &
                  row.householdId.equals(_scope.householdId),
            ))
            .write(
              AccountsCompanion(favoriteMembershipId: Value(membershipId)),
            );
    if (updated != 1) throw const Unavailable();
    return membershipId;
  }

  Future<String?> _cachedMembershipId() async {
    final account =
        await (_db.select(_db.accounts)..where(
              (row) =>
                  row.userId.equals(_scope.userId) &
                  row.householdId.equals(_scope.householdId),
            ))
            .getSingleOrNull();
    return account?.favoriteMembershipId;
  }

  JoinedSelectStatement<HasResultSet, Object?> _favorites() {
    final favorite = _db.userFavorites;
    final recipe = _db.recipes;
    final account = _db.accounts;
    return _db.select(favorite).join([
      innerJoin(
        recipe,
        recipe.id.equalsExp(favorite.recipeId),
        useColumns: false,
      ),
      innerJoin(
        account,
        account.userId.equalsExp(favorite.userId),
        useColumns: false,
      ),
    ])..where(
      favorite.userId.equals(_scope.userId) &
          account.householdId.equals(_scope.householdId) &
          favorite.recipeHouseholdId.equals(_scope.householdId) &
          recipe.householdId.equals(_scope.householdId) &
          (account.favoriteMembershipId.isNull() |
              account.favoriteMembershipId.equalsExp(favorite.membershipId)) &
          favorite.isFavorite.equals(true),
    );
  }

  Set<String> _recipeIds(List<TypedResult> rows) => Set.unmodifiable({
    for (final row in rows) row.readTable(_db.userFavorites).recipeId,
  });
}
