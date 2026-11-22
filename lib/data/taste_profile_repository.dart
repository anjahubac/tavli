import 'dart:convert';

import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../domain/cuisine_preferences.dart';
import '../domain/dish_kind_preferences.dart';
import '../domain/food_preferences.dart';
import '../sync/entities.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Reads and saves the signed-in user's private taste profile.
class TasteProfileRepository {
  TasteProfileRepository(
    this._db, {
    required AccountScope scope,
    required SyncedWriter writer,
  }) : _userId = scope.userId,
       _writer = writer {
    if (scope.userId.isEmpty || writer.accountId != scope.userId) {
      throw ArgumentError('Profil i red za slanje moraju pripadati nalogu.');
    }
  }

  final AppDatabase _db;
  final String _userId;
  final SyncedWriter _writer;

  Future<DishKindPreferences> getDishPreferences() async =>
      DishKindPreferences.fromJson(await _profile());

  Stream<DishKindPreferences> watchDishPreferences() =>
      _watchProfile().map(DishKindPreferences.fromJson);

  Future<void> saveDishPreferences(DishKindPreferences preferences) =>
      _saveFields(preferences.toJson());

  Future<FoodPreferences> getFoodPreferences() async =>
      FoodPreferences.fromJson(await _profile());

  Stream<FoodPreferences> watchFoodPreferences() =>
      _watchProfile().map(FoodPreferences.fromJson);

  Future<void> saveFoodPreferences(FoodPreferences preferences) =>
      _saveFields(preferences.toJson());

  Future<CuisinePreferences> getCuisinePreferences() async =>
      CuisinePreferences.fromJson(await _profile());

  Stream<CuisinePreferences> watchCuisinePreferences() =>
      _watchProfile().map(CuisinePreferences.fromJson);

  Future<void> saveCuisinePreferences(CuisinePreferences preferences) =>
      _saveFields(preferences.toJson());

  Future<Map<String, Object?>> _profile() async =>
      _decodeProfile(await _profileQuery().getSingleOrNull());

  Stream<Map<String, Object?>> _watchProfile() =>
      _profileQuery().watchSingleOrNull().map(_decodeProfile);

  Future<void> _saveFields(Map<String, Object?> fields) =>
      _db.transaction(() async {
        final profile = await _profile();
        profile.addAll(fields);

        await _db
            .into(_db.userProfiles)
            .insertOnConflictUpdate(
              UserProfilesCompanion.insert(
                id: _userId,
                profileJson: jsonEncode(profile),
              ),
            );
        await _writer.upsert(const TasteProfileEntity().name, _userId);
      });

  SimpleSelectStatement<$UserProfilesTable, UserProfileRow> _profileQuery() =>
      _db.select(_db.userProfiles)..where((row) => row.id.equals(_userId));

  Map<String, Object?> _decodeProfile(UserProfileRow? row) {
    if (row == null) return {};
    final decoded = jsonDecode(row.profileJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Profil ukusa mora biti JSON objekat.');
    }
    return Map<String, Object?>.from(decoded);
  }
}
