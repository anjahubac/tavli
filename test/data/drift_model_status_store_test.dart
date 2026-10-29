import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/drift_model_status_store.dart';

const model = ModelSpec(
  provider: AIProvider.gemini,
  model: 'pro',
  label: 'Gemini Pro',
);

void main() {
  late AppDatabase db;
  late DriftModelStatusStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftModelStatusStore(db);
  });
  tearDown(() => db.close());

  test('pauza se čuva posebno za sopstveni i ugrađeni ključ', () async {
    final until = DateTime.utc(2026, 10, 30, 8);
    await store.block(model, until, 'limit', origin: KeyOrigin.builtIn);

    final stored = await store.blockedUntil(model, origin: KeyOrigin.builtIn);
    expect(stored!.isAtSameMomentAs(until), isTrue);
    expect(await store.blockedUntil(model), isNull);
  });

  test('zahtevi se broje po ključu', () async {
    final at = DateTime.utc(2026, 10, 30, 12);
    await store.recordRequest(model, at);
    await store.recordRequest(model, at);
    await store.recordRequest(model, at, origin: KeyOrigin.builtIn);

    final rows = await db.select(db.modelStatuses).get();
    final byOrigin = {for (final r in rows) r.keyOrigin: r.requestsToday};
    expect(byOrigin, {'user': 2, 'builtIn': 1});
  });

  test('migracija sa verzije 1 pravi novu tabelu statusa', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE model_statuses (provider TEXT NOT NULL, '
          'model TEXT NOT NULL, blocked_until INTEGER, '
          'requests_today INTEGER NOT NULL DEFAULT 0, usage_day TEXT, '
          'last_error TEXT, PRIMARY KEY (provider, model))',
        );
        raw.execute(
          "INSERT INTO model_statuses (provider, model) VALUES ('gemini', 'pro')",
        );
        raw.execute('PRAGMA user_version = 1');
      },
    );
    final old = AppDatabase(executor);
    addTearDown(old.close);

    expect(old.schemaVersion, 2);
    expect(await old.select(old.modelStatuses).get(), isEmpty);
    await DriftModelStatusStore(old)
        .block(model, DateTime.utc(2026), 'x', origin: KeyOrigin.builtIn);
    expect(
      (await old
              .customSelect('SELECT COUNT(*) AS c FROM model_statuses')
              .getSingle())
          .read<int>('c'),
      1,
    );
  });
}
