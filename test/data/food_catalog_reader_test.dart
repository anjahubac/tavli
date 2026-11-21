import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/food_catalog_reader.dart';
import 'package:tavli/domain/food_matcher.dart';
import 'package:tavli/domain/shopping_sync.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli/sync/downloader.dart';

import '../helpers/fake_backend.dart';

void main() {
  late AppDatabase db;
  final t = DateTime.utc(2026, 11);
  const home = FoodLookupScope(householdId: 'h1');

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> food(String id, {String? household, String unit = 'gram'}) => db
      .into(db.foods)
      .insert(
        FoodsCompanion.insert(
          id: id,
          householdId: Value(household),
          slug: id,
          name: 'namirnica $id',
          category: 'Ostalo',
          baseUnit: unit,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> alias(
    String id,
    String foodId,
    String key, {
    String? household,
  }) => db
      .into(db.foodAliases)
      .insert(
        FoodAliasesCompanion.insert(
          id: id,
          foodId: foodId,
          householdId: Value(household),
          alias: key,
          aliasNormalized: key,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<FoodMatchResult> find(String text) async =>
      (await FoodCatalogReader(db).matcherFor(home))
          .findByName(originalText: text, scope: home);

  String? matchedId(FoodMatchResult r) => r is Matched ? r.food.id : null;

  test('prazan keš: svako ime je Unresolved', () async {
    expect(await find('jaja'), isA<Unresolved>());
  });

  test('poklapa sačuvan alias_normalized (izlaz ingredientKey)', () async {
    await food('f-jaje');
    await alias('a1', 'f-jaje', ingredientKey('Jaja'));
    expect(matchedId(await find('Jaja')), 'f-jaje');
  });

  test('tuđe domaćinstvo i nepoznata jedinica se ne vide', () async {
    await food('f-tudja', household: 'h2');
    await alias('a1', 'f-tudja', 'ajvar', household: 'h2');
    await food('f-cudna', unit: 'kilogram');
    await alias('a2', 'f-cudna', 'brasno');
    await alias('a3', 'f-nema', 'so');
    expect(await find('ajvar'), isA<Unresolved>());
    expect(await find('brasno'), isA<Unresolved>());
    expect(await find('so'), isA<Unresolved>());
  });

  test('zamena kućnog aliasa pre traga: Unresolved, posle traga nova '
      'namirnica', () async {
    final backend = FakeBackend();
    final s = await backend.auth.verifyCode('ana@mail.com', FakeServer.code);
    final hid = backend.server.households[s.userId]!;
    final scope = FoodLookupScope(householdId: hid);
    Downloader downloader() => Downloader(
      db: db,
      remote: backend.sync,
      scope: AccountScope(userId: s.userId, householdId: hid),
    );
    void serverFood(String id) => backend.server.upsert('foods', [
      {
        'id': id,
        'household_id': null,
        'slug': id,
        'name': 'namirnica $id',
        'category': 'Ostalo',
        'base_unit': 'gram',
        'created_at': '2026-11-01T10:00:00.000Z',
      },
    ], 'id');
    void serverAlias(String id, String foodId) =>
        backend.server.upsert('food_aliases', [
          {
            'id': id,
            'food_id': foodId,
            'household_id': hid,
            'alias': 'ajvar',
            'alias_normalized': 'ajvar',
            'created_at': '2026-11-01T10:00:00.000Z',
          },
        ], 'id');
    Future<FoodMatchResult> findHere() async =>
        (await FoodCatalogReader(db).matcherFor(scope))
            .findByName(originalText: 'ajvar', scope: scope);

    serverFood('x');
    serverFood('y');
    serverAlias('old', 'x');
    await downloader().run();
    expect(matchedId(await findHere()), 'x');

    // Drugi uređaj: upis nove veze stigao, brisanje stare još nije.
    serverAlias('new', 'y');
    await downloader().run();
    expect(await findHere(), isA<Unresolved>());

    backend.server.delete('food_aliases', ['old'], 'id');
    await downloader().run();
    expect(matchedId(await findHere()), 'y');
  });

  group('status kataloga', () {
    Future<FoodMatchResult> find(CatalogStatus status) async =>
        (await FoodCatalogReader(db).matcherFor(
          home,
          status: status,
        )).findByName(originalText: 'namirnica f1', scope: home);

    test(
      'notOnServer: popunjen keš se ne čita, svako ime je Unresolved',
      () async {
        await food('f1');
        expect(await find(CatalogStatus.available), isA<Matched>());
        expect(await find(CatalogStatus.notOnServer), isA<Unresolved>());
      },
    );
  });
}
