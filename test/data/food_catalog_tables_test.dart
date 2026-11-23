import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  FoodAliasesCompanion alias(
    String id, {
    String? householdId,
    String key = 'jaja',
    DateTime? withdrawnAt,
  }) => FoodAliasesCompanion.insert(
    id: id,
    foodId: 'f1',
    householdId: Value(householdId),
    alias: key,
    aliasNormalized: key,
    withdrawnAt: Value(withdrawnAt),
    createdAt: DateTime.utc(2026, 11),
    updatedAt: DateTime.utc(2026, 11),
  );

  test('dva kućna aliasa istog ključa se primaju', () async {
    await db.into(db.foodAliases).insert(alias('a1', householdId: 'h1'));
    await db.into(db.foodAliases).insert(alias('a2', householdId: 'h1'));
    expect(await db.select(db.foodAliases).get(), hasLength(2));
  });

  test('dva aktivna deljena aliasa istog ključa se odbijaju', () async {
    await db.into(db.foodAliases).insert(alias('a1'));
    await expectLater(
      db.into(db.foodAliases).insert(alias('a2')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('povučen deljeni alias i zamena pod istim ključem se primaju', () async {
    await db
        .into(db.foodAliases)
        .insert(alias('a1', withdrawnAt: DateTime.utc(2026, 11, 2)));
    await db.into(db.foodAliases).insert(alias('a2'));
    expect(await db.select(db.foodAliases).get(), hasLength(2));
  });

  test('povučen red zamenjuje keširan red istog id-ja', () async {
    await db.into(db.foodAliases).insert(alias('a1'));
    await db
        .into(db.foodAliases)
        .insertOnConflictUpdate(
          alias('a1', withdrawnAt: DateTime.utc(2026, 11, 2)),
        );
    await db.into(db.foodAliases).insert(alias('a2'));
    final rows = await db.select(db.foodAliases).get();
    expect(rows, hasLength(2));
    expect(rows.firstWhere((r) => r.id == 'a1').withdrawnAt, isNotNull);
  });
}
