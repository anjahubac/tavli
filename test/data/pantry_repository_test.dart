import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/pantry_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  const home = AccountScope(userId: 'one', householdId: 'home-one');
  final now = DateTime.utc(2026, 11, 2, 9);
  late AppDatabase db;
  late ShoppingRepository shop;
  late PantryRepository pantry;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final writer = SyncedWriter(db, accountId: 'one', clock: () => now);
    shop = ShoppingRepository(
      db,
      scope: home,
      writer: writer,
      clock: () => now,
    );
    pantry = PantryRepository(
      db,
      scope: home,
      writer: writer,
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  test(
    'prijem kupljenog: potvrđena zaliha vezana za kupovinu, jednom',
    () async {
      final list = await shop.recipeList();
      final mleko = await shop.addManual(
        list,
        'Mleko',
        quantity: 1,
        unit: 'l',
        category: 'mlečni proizvodi i jaja',
      );
      final hleb = await shop.addManual(list, 'Hleb');

      // Nekupljeno se ne prima.
      expect(await pantry.receivePurchases([mleko]), 0);
      await shop.setBought([mleko, hleb], bought: true);
      expect(await pantry.receivePurchases([mleko, mleko, hleb]), 2);
      expect(await pantry.receivePurchases([mleko]), 0);

      final rows = await db.select(db.pantryItems).get();
      final milk = rows.firstWhere((r) => r.name == 'Mleko');
      expect(milk.quantity, 1);
      expect(milk.unit, 'l');
      expect(milk.category, 'mlečni proizvodi i jaja');
      expect(milk.confirmedAt!.isAtSameMomentAs(now), isTrue);
      expect(milk.sourceShoppingItemId, mleko);
      expect(milk.householdId, 'home-one');
      expect(await pantry.watchReceivedItemIds().first, {mleko, hleb});

      final outbox = await (db.select(
        db.syncOutbox,
      )..where((t) => t.entity.equals('pantry_item'))).get();
      expect(outbox, hasLength(2));
    },
  );

  test('druga osoba ne prima tuđu kupovinu', () async {
    final list = await shop.recipeList();
    final id = await shop.addManual(list, 'Mleko');
    await shop.setBought([id], bought: true);
    final other = PantryRepository(
      db,
      scope: const AccountScope(userId: 'two', householdId: 'home-two'),
      writer: SyncedWriter(db, accountId: 'two'),
    );
    expect(await other.receivePurchases([id]), 0);
    expect(await other.watchReceivedItemIds().first, isEmpty);
    expect(await db.select(db.pantryItems).get(), isEmpty);
  });
}
