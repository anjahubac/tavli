import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/sync/synced_writer.dart';

const krompir = Ingredient(name: 'Krompir', quantity: 1, unit: 'kg');
const meso = Ingredient(name: 'Mleveno meso', quantity: 500, unit: 'g');
const luk = Ingredient(name: 'Crni luk', quantity: 2, unit: 'kom');

void main() {
  late AppDatabase db;
  late ShoppingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ShoppingRepository(
      db,
      scope: const AccountScope(userId: 'one', householdId: 'home-one'),
      writer: SyncedWriter(db, accountId: 'one'),
    );
  });

  tearDown(() => db.close());

  test('kupovina je odvojena po domaćinstvu i upisuje outbox sa UUID-jevima', () async {
    await repo.addMissing('musaka', missing: const [luk], have: const []);
    final other = ShoppingRepository(
      db,
      scope: const AccountScope(userId: 'two', householdId: 'home-two'),
      writer: SyncedWriter(db, accountId: 'two'),
    );
    expect(await other.openNames(), isEmpty);
    await other.addMissing('sarma', missing: const [krompir], have: const []);
    expect(await repo.openNames(), ['Crni luk']);
    expect(await other.openNames(), ['Krompir']);
    final outbox = await db.select(db.syncOutbox).get();
    expect(
      outbox.where((r) => r.accountId == 'one').map((r) => r.entity),
      containsAll(['shopping_list', 'shopping_item']),
    );
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (final row in outbox) {
      expect(uuid.hasMatch(row.recordId), isTrue);
    }
    await repo.markHave('musaka', luk);
    final deleted = await (db.select(
      db.syncOutbox,
    )..where((r) => r.op.equals(OutboxOp.delete))).get();
    expect(deleted.single.entity, 'shopping_item');
    expect(deleted.single.accountId, 'one');
  });

  test(
    '3 sastojka, imam 2 → dodaje 1; odštikliram jedan → dodaje samo njega',
    () async {
      // Imam meso i luk; nedostaje krompir.
      var added = await repo.addMissing(
        'musaka',
        missing: const [krompir],
        have: const [meso, luk],
      );
      expect(added.map((i) => i.name), ['Krompir']);
      expect(await repo.openNames(), ['Krompir']);

      // Ponovni klik bez promene ne dodaje ništa.
      added = await repo.addMissing(
        'musaka',
        missing: const [krompir],
        have: const [meso, luk],
      );
      expect(added, isEmpty);

      // Ipak nemam luk: dodaje se samo luk, krompir se ne duplira.
      final plan = await repo.plan(
        'musaka',
        missing: const [krompir, luk],
        have: const [meso],
      );
      expect(plan.toAdd.map((i) => i.name), ['Crni luk']);
      added = await repo.addMissing(
        'musaka',
        missing: const [krompir, luk],
        have: const [meso],
      );
      expect(added.map((i) => i.name), ['Crni luk']);
      expect(await repo.openNames(), ['Krompir', 'Crni luk']);
      expect(await repo.openCount(), 2);
    },
  );

  test(
    'štikliram "imam" za stavku koju je recept dodao → izlazi iz kupovine',
    () async {
      await repo.addMissing(
        'musaka',
        missing: const [krompir, luk],
        have: const [meso],
      );
      expect(await repo.markHave('musaka', luk), isTrue);
      expect(await repo.openNames(), ['Krompir']);
      // Ponovo ga nemam: vraća se jednom.
      await repo.addMissing(
        'musaka',
        missing: const [krompir, luk],
        have: const [meso],
      );
      expect(await repo.openNames(), ['Krompir', 'Crni luk']);
    },
  );

  test('kupljena stavka ostaje i kad je označim kao "imam"', () async {
    await repo.addMissing('musaka', missing: const [luk], have: const []);
    await repo.markBought('Crni luk');
    expect(await repo.markHave('musaka', luk), isFalse);
    expect(await repo.openCount(), 0);
  });

  test('isti sastojak iz dva recepta je jedna stavka; "imam" u jednom je ne '
      'briše za drugi', () async {
    await repo.addMissing('musaka', missing: const [luk], have: const []);
    await repo.addMissing('sarma', missing: const [luk], have: const []);
    expect(await repo.openNames(), ['Crni luk']);

    await repo.markHave('musaka', luk);
    expect(await repo.openNames(), ['Crni luk']);
    await repo.markHave('sarma', luk);
    expect(await repo.openNames(), isEmpty);
  });
}
