import 'dart:convert';

import '../account/auth_controller.dart';
import '../domain/dish_kind_preferences.dart';
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

  Future<DishKindPreferences> getDishPreferences() async {
    final row = await _profileRow();
    if (row == null) return DishKindPreferences();
    return DishKindPreferences.fromJson(_decodeProfile(row.profileJson));
  }

  Stream<DishKindPreferences> watchDishPreferences() =>
      (_db.select(
        _db.userProfiles,
      )..where((row) => row.id.equals(_userId))).watchSingleOrNull().map(
        (row) => row == null
            ? DishKindPreferences()
            : DishKindPreferences.fromJson(_decodeProfile(row.profileJson)),
      );

  Future<void> saveDishPreferences(DishKindPreferences preferences) =>
      _db.transaction(() async {
        final row = await _profileRow();
        final profile = row == null
            ? <String, Object?>{}
            : _decodeProfile(row.profileJson);
        profile.addAll(preferences.toJson());

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

  Future<UserProfileRow?> _profileRow() => (_db.select(
    _db.userProfiles,
  )..where((row) => row.id.equals(_userId))).getSingleOrNull();

  Map<String, Object?> _decodeProfile(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Profil ukusa mora biti JSON objekat.');
    }
    return Map<String, Object?>.from(decoded);
  }
}
