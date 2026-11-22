import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/allergen_repository.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/sync/entities.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  test(
    'atomically replaces and clears only the active member selection',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      AllergenRepository repository(String user) => AllergenRepository(
        db,
        scope: AccountScope(userId: user, householdId: 'shared'),
        writer: SyncedWriter(db, accountId: user),
      );
      final first = repository('first');
      final second = repository('second');
      expect(await first.watchSelection().first, isEmpty);
      await first.saveSelection({AllergenGroup.nuts, AllergenGroup.gluten});
      await second.saveSelection({AllergenGroup.soy});
      expect(await first.watchSelection().first, {
        AllergenGroup.gluten,
        AllergenGroup.nuts,
      });
      const entity = AllergenSelectionEntity();
      expect(entity.toRemote((await entity.read(db, 'first'))!), {
        'user_id': 'first',
        'group_codes': ['gluten', 'nuts'],
      });

      await first.saveSelection({});
      expect(await first.watchSelection().first, isEmpty);
      expect(await second.watchSelection().first, {AllergenGroup.soy});
      expect(
        entity.toRemote((await entity.read(db, 'first'))!)['group_codes'],
        <String>[],
      );
      final operations = await db.select(db.syncOutbox).get();
      expect(operations.map((row) => (row.accountId, row.entity, row.op)), [
        ('first', entity.name, OutboxOp.upsert),
        ('second', entity.name, OutboxOp.upsert),
      ]);
    },
  );
}
