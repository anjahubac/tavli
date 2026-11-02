import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/sync/synced_writer.dart';

void main() {
  late AppDatabase db;
  late SyncedWriter w;
  var kicks = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    kicks = 0;
    w = SyncedWriter(
      db,
      accountId: 'u1',
      clock: () => DateTime.utc(2026),
      onChange: () => kicks++,
    );
  });
  tearDown(() => db.close());

  Future<List<String>> outbox() async => [
    for (final e in await (db.select(
      db.syncOutbox,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get())
      '${e.entity}:${e.recordId}:${e.op}',
  ];

  test('upsert se dodaje jednom; ostaje raniji redni broj', () async {
    await w.upsert('recipe', 'r1');
    await w.upsert('recipe_version', 'v1');
    await w.upsert('recipe', 'r1');
    expect(await outbox(), ['recipe:r1:upsert', 'recipe_version:v1:upsert']);
    expect(kicks, 3);
  });

  test('upsertLast premešta izmenu koja čeka na kraj reda', () async {
    await w.upsert('shopping_contribution', 'c1');
    await w.upsert('shopping_item', 'i1');
    await w.upsertLast('shopping_contribution', 'c1');
    expect(await outbox(), [
      'shopping_item:i1:upsert',
      'shopping_contribution:c1:upsert',
    ]);
  });

  test('brisanje uklanja upsert-e koji čekaju i dodaje brisanje', () async {
    await w.upsert('recipe', 'r1');
    await w.upsert('recipe', 'r2');
    await w.delete('recipe', 'r1');
    expect(await outbox(), ['recipe:r2:upsert', 'recipe:r1:delete']);
  });

  test('brisanje uklanja i odbijen upsert tog zapisa', () async {
    await w.upsert('recipe', 'r1');
    await db
        .update(db.syncOutbox)
        .write(const SyncOutboxCompanion(state: Value(OutboxState.rejected)));
    await w.delete('recipe', 'r1');
    expect(await outbox(), ['recipe:r1:delete']);
  });

  test('slike: slanje jednom, brisanje poništava slanje koje čeka', () async {
    await w.photoUpload('recipe_photos/a.jpg');
    await w.photoUpload('recipe_photos/a.jpg');
    await w.photoUpload('recipe_photos/b.jpg');
    await w.photoDelete('recipe_photos/a.jpg');
    expect(await outbox(), [
      'photo:recipe_photos/b.jpg:photoUpload',
      'photo:recipe_photos/a.jpg:photoDelete',
    ]);
  });

  test('svaka izmena nosi nalog', () async {
    await w.upsert('recipe', 'r1');
    await SyncedWriter(db, accountId: 'u2').upsert('recipe', 'r1');
    final rows = await db.select(db.syncOutbox).get();
    expect(rows.map((r) => r.accountId), ['u1', 'u2']);
    expect(rows.every((r) => r.state == OutboxState.pending), isTrue);
  });

  test('neuspela transakcija ne ostavlja ni red ni izmenu', () async {
    await expectLater(
      db.transaction(() async {
        await db
            .into(db.recipes)
            .insert(
              RecipesCompanion.insert(
                id: 'r1',
                title: 'Sarma',
                servings: 4,
                source: 'manual',
                ingredientsJson: '[]',
                stepsJson: '[]',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            );
        await w.upsert('recipe', 'r1');
        throw StateError('pukla transakcija');
      }),
      throwsStateError,
    );
    expect(await db.select(db.recipes).get(), isEmpty);
    expect(await outbox(), isEmpty);
  });
}
