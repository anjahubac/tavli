import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/sync/entities.dart';

/// Kako bi red izgledao kad stigne sa servera (JSON + updated_at).
Map<String, Object?> viaServer(Map<String, Object?> remote) =>
    (jsonDecode(jsonEncode(remote)) as Map<String, Object?>)
      ..putIfAbsent('updated_at', () => '2026-10-30T12:00:00.123456+00:00');

void main() {
  late AppDatabase db;
  final t = DateTime.utc(2026, 10, 30, 10, 5, 7);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> roundTrip<R>(
    SyncEntity<Table, R> e,
    Insertable<R> local,
    String id,
    void Function(Map<String, Object?> remote) checkRemote,
  ) async {
    await db.into(e.table(db)).insert(local);
    final row = (await e.read(db, id)) as R;
    final remote = e.toRemote(row);
    checkRemote(remote);
    expect(remote.keys.every((k) => k == k.toLowerCase()), isTrue);

    await e.deleteLocal(db, id);
    expect(await e.read(db, id), isNull);
    await e.write(db, viaServer(remote));
    final back = await e.read(db, id);
    expect(e.toRemote(back as R), remote, reason: e.name);
  }

  test('recept: JSON liste, ime slike bez fascikle, UTC vreme', () async {
    await roundTrip(
      const RecipeEntity(),
      RecipesCompanion.insert(
        id: 'r1',
        title: 'Sarma',
        servings: 4,
        prepMinutes: const Value(60),
        source: 'manual',
        ingredientsJson: '[{"name":"kupus","quantity":0.5}]',
        stepsJson: '["Kuvati."]',
        imagePath: const Value('recipe_photos/a.jpg'),
        createdAt: t,
        updatedAt: t,
        householdId: const Value('h1'),
      ),
      'r1',
      (r) {
        expect(r['household_id'], 'h1');
        expect(r['ingredients'], [
          {'name': 'kupus', 'quantity': 0.5},
        ]);
        expect(r['steps'], ['Kuvati.']);
        expect(r['image_path'], 'a.jpg');
        expect(r['created_at'], '2026-10-30T10:05:07.000Z');
        expect(r.containsKey('updated_at'), isFalse);
      },
    );
    final row = (await db.select(db.recipes).get()).single;
    expect(row.imagePath, 'recipe_photos/a.jpg');
    expect(row.updatedAt.toUtc(), DateTime.utc(2026, 10, 30, 12));
  });

  test('verzija recepta', () async {
    await roundTrip(
      const RecipeVersionEntity(),
      RecipeVersionsCompanion.insert(
        id: 'v1',
        recipeId: 'r1',
        recipeJson: '{"title":"Sarma"}',
        createdAt: t,
        changeKind: const Value('manual'),
        instruction: const Value('posno'),
        householdId: const Value('h1'),
      ),
      'v1',
      (r) {
        expect(r['recipe_json'], {'title': 'Sarma'});
        expect(r['recipe_id'], 'r1');
      },
    );
  });

  test('lista i stavka za kupovinu', () async {
    await roundTrip(
      const ShoppingListEntity(),
      ShoppingListsCompanion.insert(
        id: 'l1',
        name: 'Lista',
        createdAt: t,
        mealPlanId: const Value('p1'),
        week: const Value(2),
        householdId: const Value('h1'),
      ),
      'l1',
      (r) => expect(r['meal_plan_id'], 'p1'),
    );
    await roundTrip(
      const ShoppingItemEntity(),
      ShoppingItemsCompanion.insert(
        id: 'i1',
        listId: 'l1',
        name: 'mleko',
        category: 'ostalo',
        quantity: const Value(1.5),
        isBought: const Value(true),
        fromRecipeIdsJson: const Value('["r1"]'),
        householdId: const Value('h1'),
      ),
      'i1',
      (r) {
        expect(r['from_recipe_ids'], ['r1']);
        expect(r['is_bought'], isTrue);
      },
    );
  });

  test('ostava, plan i stavka plana', () async {
    await roundTrip(
      const PantryItemEntity(),
      PantryItemsCompanion.insert(
        id: 'o1',
        name: 'so',
        category: 'ostalo',
        addedAt: t,
        expiresAt: Value(t.add(const Duration(days: 3))),
        householdId: const Value('h1'),
      ),
      'o1',
      (r) => expect(r['expires_at'], '2026-11-02T10:05:07.000Z'),
    );
    await roundTrip(
      const MealPlanEntity(),
      MealPlansCompanion.insert(
        id: 'p1',
        startDate: t,
        endDate: t,
        mealTypesJson: '["lunch"]',
        createdAt: t,
        householdId: const Value('h1'),
      ),
      'p1',
      (r) => expect(r['meal_types'], ['lunch']),
    );
    await roundTrip(
      const MealPlanEntryEntity(),
      MealPlanEntriesCompanion.insert(
        id: 'e1',
        planId: 'p1',
        date: t,
        mealType: 'lunch',
        recipeId: const Value('r1'),
        householdId: const Value('h1'),
      ),
      'e1',
      (r) => expect(r['plan_id'], 'p1'),
    );
  });

  test('ocena i profil ukusa pripadaju osobi', () async {
    await roundTrip(
      const RatingEntity(),
      RatingsCompanion.insert(
        id: 'g1',
        recipeId: 'r1',
        stars: 5,
        cookedAt: t,
        userId: const Value('u1'),
      ),
      'g1',
      (r) {
        expect(r['user_id'], 'u1');
        expect(r.containsKey('household_id'), isFalse);
      },
    );
    await roundTrip(
      const TasteProfileEntity(),
      UserProfilesCompanion.insert(id: 'u1', profileJson: '{"ljuto":true}'),
      'u1',
      (r) => expect(r, {
        'user_id': 'u1',
        'profile': {'ljuto': true},
      }),
    );
  });

  test('registar: roditelj uvek pre deteta', () {
    final names = [for (final e in syncEntities) e.name];
    for (final e in syncEntities) {
      if (e.parent case final p?) {
        expect(names.indexOf(p), lessThan(names.indexOf(e.name)));
      }
    }
    expect(names, hasLength(9));
    expect(entityByName('recipe'), isA<RecipeEntity>());
    expect(entityByName('nema'), isNull);
  });
}
