import 'dart:convert';

import '../account/auth_controller.dart';
import '../domain/allergen_group.dart';
import '../sync/entities.dart';
import '../sync/synced_writer.dart';
import 'database.dart';

/// Local settings for the active account's own allergen selection.
class AllergenRepository {
  AllergenRepository(
    this._db, {
    required AccountScope scope,
    required SyncedWriter writer,
  }) : _userId = scope.userId,
       _writer = writer {
    if (_userId.isEmpty || writer.accountId != _userId) {
      throw ArgumentError('Izbor alergena mora pripadati aktivnom nalogu.');
    }
  }

  static const _entity = AllergenSelectionEntity();

  final AppDatabase _db;
  final String _userId;
  final SyncedWriter _writer;

  Future<Set<AllergenGroup>> getSelection() async =>
      _decode(await _entity.read(_db, _userId));

  Stream<Set<AllergenGroup>> watchSelection() =>
      (_db.select(_db.userAllergenSelections)
            ..where((row) => row.userId.equals(_userId)))
          .watchSingleOrNull()
          .map(_decode);

  Future<void> saveSelection(Set<AllergenGroup> selection) {
    final codes = jsonEncode([
      for (final group in AllergenGroup.values)
        if (selection.contains(group)) group.code,
    ]);
    return _db.transaction(() async {
      await _db
          .into(_db.userAllergenSelections)
          .insertOnConflictUpdate(
            UserAllergenSelectionsCompanion.insert(
              userId: _userId,
              groupCodesJson: codes,
            ),
          );
      await _writer.upsert(_entity.name, _userId);
    });
  }

  static Set<AllergenGroup> _decode(UserAllergenSelectionRow? row) =>
      row == null
      ? const {}
      : AllergenGroup.parseSelection(jsonDecode(row.groupCodesJson));
}
