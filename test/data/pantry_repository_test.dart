import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/pantry_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/food_matcher.dart';
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

  Future<void> put(
    String id,
    String name, {
    double? quantity,
    String? unit,
    String household = 'home-one',
  }) => db
      .into(db.pantryItems)
      .insert(
        PantryItemsCompanion.insert(
          id: id,
          name: name,
          quantity: Value(quantity),
          unit: Value(unit),
          category: 'ostalo',
          addedAt: now,
          householdId: Value(household),
        ),
      );

  test('namirnice domaćinstva po nazivu, sa raspoloživom količinom', () async {
    await put('a', 'mleko', quantity: 1, unit: 'l');
    await put('b', 'Brašno');
    await put('c', 'Jaja', quantity: 6, unit: 'kom');
    await put('d', 'Tuđe', household: 'home-two');

    final entries = await pantry.watchEntries().first;
    expect([for (final e in entries) e.name], ['Brašno', 'Jaja', 'mleko']);
    expect([for (final e in entries) e.quantity], [null, 6, 1]);
    expect(entries.last.unit, 'l');
  });

  test(
    'uklanjanje briše namirnicu i njenu potrošnju, i ide na server',
    () async {
      await put('a', 'Mleko', quantity: 1, unit: 'l');
      await put('b', 'Brašno');
      await db
          .into(db.pantryConsumptions)
          .insert(
            PantryConsumptionsCompanion.insert(
              id: 'c1',
              householdId: const Value('home-one'),
              eventId: 'e1',
              pantryItemId: 'a',
              baseUnit: 'ml',
              micros: 1,
              createdAt: now,
            ),
          );

      await pantry.remove('a');
      expect([for (final e in await pantry.watchEntries().first) e.id], ['b']);
      expect(await db.select(db.pantryConsumptions).get(), isEmpty);
      final outbox = await (db.select(
        db.syncOutbox,
      )..where((t) => t.entity.equals('pantry_item'))).get();
      expect([for (final o in outbox) (o.recordId, o.op)], [('a', 'delete')]);

      // Tuđa ili nepostojeća namirnica: ništa se ne menja.
      await put('x', 'Tuđe', household: 'home-two');
      await pantry.remove('x');
      await pantry.remove('nema');
      expect(await db.select(db.pantryItems).get(), hasLength(2));
      expect(
        await (db.select(
          db.syncOutbox,
        )..where((t) => t.entity.equals('pantry_item'))).get(),
        hasLength(1),
      );
    },
  );

  test(
    'dodavanje: novi red, spajanje iste jedinice, druga jedinica je novi red',
    () async {
      final first = await pantry.add('  Mleko ', quantity: 1, unit: 'l');
      var rows = await db.select(db.pantryItems).get();
      expect(rows.single.name, 'Mleko');
      expect(rows.single.confirmedAt, isNotNull);
      expect(rows.single.sourceShoppingItemId, isNull);
      expect(rows.single.householdId, 'home-one');

      // Ista namirnica i jedinica: količina se dodaje.
      expect(await pantry.add('mleko', quantity: 0.5, unit: 'l'), first);
      expect((await db.select(db.pantryItems).get()).single.quantity, 1.5);

      // Bez količine: postojeći red se ne menja.
      expect(await pantry.add('MLEKO'), first);
      expect((await db.select(db.pantryItems).get()).single.quantity, 1.5);

      // Druga jedinica: poseban red.
      final other = await pantry.add('Mleko', quantity: 200, unit: 'ml');
      expect(other, isNot(first));
      rows = await db.select(db.pantryItems).get();
      expect(rows, hasLength(2));

      final outbox = await (db.select(
        db.syncOutbox,
      )..where((t) => t.entity.equals('pantry_item'))).get();
      expect({for (final o in outbox) o.recordId}, {first, other});
    },
  );

  test('dodavanje bez količine, pa sa količinom upisuje količinu', () async {
    final id = await pantry.add('Brašno');
    var row = (await db.select(db.pantryItems).get()).single;
    expect([row.quantity, row.unit, row.quantitySetAt], [null, null, null]);

    expect(await pantry.add('Brašno', quantity: 1, unit: 'kg'), id);
    row = (await db.select(db.pantryItems).get()).single;
    expect([row.quantity, row.unit], [1, 'kg']);
    expect(row.quantitySetAt, isNotNull);
  });

  test('dodavanje odbija prazan naziv i neispravnu količinu', () async {
    expect(() => pantry.add('  '), throwsArgumentError);
    expect(() => pantry.add('So', quantity: 0), throwsArgumentError);
    expect(() => pantry.add('So', quantity: -1), throwsArgumentError);
    expect(await db.select(db.pantryItems).get(), isEmpty);
  });

  test('addAll upisuje sve stavke i spaja iste', () async {
    await pantry.add('Mleko', quantity: 1, unit: 'l');
    await pantry.addAll([
      (name: 'mleko', quantity: 2.0, unit: 'l', category: 'ostalo'),
      (name: 'Hleb', quantity: null, unit: null, category: 'ostalo'),
    ]);
    final rows = await pantry.watchEntries().first;
    expect(rows.map((e) => e.name), ['Hleb', 'Mleko']);
    expect(rows.last.quantity, 3);
  });

  test('setQuantity menja jedinicu samo uz changeUnit', () async {
    final id = await pantry.add('Brašno', quantity: 1, unit: 'kg');
    await pantry.setQuantity(id, 500);
    var row = (await db.select(db.pantryItems).get()).single;
    expect([row.quantity, row.unit], [500, 'kg']);
    await pantry.setQuantity(id, 500, unit: 'g', changeUnit: true);
    row = (await db.select(db.pantryItems).get()).single;
    expect([row.quantity, row.unit], [500, 'g']);
    await pantry.setQuantity(id, null, changeUnit: true);
    row = (await db.select(db.pantryItems).get()).single;
    expect([row.quantity, row.unit], [null, null]);
  });

  test('ista namirnica i jedinica su jedan red sa zbirom', () async {
    await put('a', 'Mleko', quantity: 1, unit: 'l');
    await put('b', 'mleko', quantity: 2, unit: 'l');
    await put('c', 'Mleko');
    await put('d', 'Mleko', quantity: 500, unit: 'ml');
    await put('e', 'So');
    await put('f', 'so');

    final entries = await pantry.watchEntries().first;
    expect(
      [for (final e in entries) (e.name, e.quantity, e.unit)],
      [('Mleko', 3, 'l'), ('Mleko', 500, 'ml'), ('So', null, null)],
    );
    expect(entries.first.ids, ['a', 'b', 'c']);
    expect(entries.last.ids, ['e', 'f']);
  });

  test('prijem iz nabavke povećava postojeću namirnicu u ostavi', () async {
    await pantry.add('Mleko', quantity: 1, unit: 'l');
    final list = await shop.recipeList();
    final kupljeno = await shop.addManual(
      list,
      'Mleko',
      quantity: 2,
      unit: 'l',
    );
    await shop.setBought([kupljeno], bought: true);
    await pantry.receivePurchases([kupljeno]);

    final entries = await pantry.watchEntries().first;
    expect([for (final e in entries) (e.name, e.quantity)], [('Mleko', 3)]);
  });

  test(
    'uklonjena primljena kupovina ostaje primljena i ne vraća se u nabavku',
    () async {
      final list = await shop.recipeList();
      final kupljeno = await shop.addManual(
        list,
        'Mleko',
        quantity: 1,
        unit: 'l',
      );
      await shop.setBought([kupljeno], bought: true);
      await pantry.receivePurchases([kupljeno]);

      final entry = (await pantry.watchEntries().first).single;
      await pantry.removeEntry(entry);
      expect(await pantry.watchEntries().first, isEmpty);
      expect(await pantry.watchReceivedItemIds().first, {kupljeno});
      expect(await pantry.receivePurchases([kupljeno]), 0);

      // Ponovo dodata, ista namirnica opet je vidljiva.
      await pantry.add('mleko');
      expect(
        [
          for (final e in await pantry.watchEntries().first)
            (e.name, e.quantity),
        ],
        [('Mleko', null)],
      );
    },
  );

  test('ručno brojanje cele namirnice upisuje tačan zbir', () async {
    await put('a', 'Jaja', quantity: 6, unit: 'kom');
    await put('b', 'Jaja', quantity: 4, unit: 'kom');
    await put('c', 'Jaja');
    final entry = (await pantry.watchEntries().first).single;
    await pantry.setEntryQuantity(entry, 3, unit: 'kom');

    final entries = await pantry.watchEntries().first;
    expect([for (final e in entries) (e.quantity, e.unit)], [(3, 'kom')]);
    expect(
      [for (final r in await db.select(db.pantryItems).get()) r.id],
      ['a'],
    );
  });

  test('šta imam: količina i id iz kataloga po nazivu ili aliasu', () async {
    await put('a', 'Mleko', quantity: 1, unit: 'l');
    await put('b', 'Brašno');
    const milk = FoodIdentity(
      id: 'food-milk',
      slug: 'mleko',
      name: 'mleko',
      category: 'mlečni proizvodi i jaja',
      baseUnit: FoodBaseUnit.milliliter,
    );
    final stock = await pantry.whatIHave(_OneFood('mleko', milk));
    expect(
      [for (final s in stock) (s.name, s.foodId, s.quantity, s.unit)],
      [('Brašno', null, null, null), ('Mleko', 'food-milk', 1, 'l')],
    );
  });
}

/// Katalog sa jednom namirnicom: poklapa naziv bez obzira na velika slova.
class _OneFood implements FoodMatcher {
  _OneFood(this.key, this.food);

  final String key;
  final FoodIdentity food;

  @override
  Future<FoodMatchResult> findByName({
    required String originalText,
    required FoodLookupScope scope,
  }) async => originalText.trim().toLowerCase() == key
      ? Matched(food)
      : const Unresolved();
}
