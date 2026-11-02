import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_demand.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/sync/synced_writer.dart';

const scope = AccountScope(userId: 'one', householdId: 'home-one');

/// Pada na [failAt]-tom upisu u outbox (simulira kvar usred čuvanja).
class FailingWriter extends SyncedWriter {
  FailingWriter(super.db, {required super.accountId});

  int? failAt;
  var _count = 0;

  @override
  Future<void> upsert(String entity, String id) async {
    if (failAt != null && ++_count >= failAt!) {
      throw StateError('kvar pri upisu');
    }
    return super.upsert(entity, id);
  }
}

final monday = CivilDate(2026, 11, 2);

RecipeSnapshot snapshot(String title, {double kg = 1}) => RecipeSnapshot(
  title: title,
  baseServings: 4,
  ingredients: [Ingredient(name: 'krompir', quantity: kg, unit: 'kg')],
);

/// Nacrt za [days] dana ručka: dan 1 je recept iz biblioteke "r1", ostali
/// novi recepti; [ready] ograničava koliko novih recepata ima sastojke.
PlanDraft draft({int days = 3, int? ready, PlanBase? base}) {
  final request = PlanRequest(
    range: DateRange(monday, monday.addDays(days - 1)),
    mealTypes: const {MealType.lunch},
  );
  final slots = request.slots;
  final proposals = <MealSlot, SlotProposal>{
    slots.first: const SlotProposal(title: 'Pasulj', libraryRecipeId: 'r1'),
    for (final s in slots.skip(1))
      s: SlotProposal(
        title: 'Jelo ${s.date.day}',
        draftRecipeKey: 'jelo ${s.date.day}',
      ),
  };
  final keys = [for (final s in slots.skip(1)) 'jelo ${s.date.day}'];
  return PlanDraft(
    request: request,
    proposals: proposals,
    libraryRecipes: {'r1': snapshot('Pasulj')},
    newRecipes: {
      for (final k in keys.take(ready ?? keys.length)) k: snapshot('Jelo $k'),
    },
    base: base,
  );
}

void main() {
  late AppDatabase db;
  late FailingWriter writer;
  late MealPlanRepository repo;

  MealPlanRepository makeRepo(AccountScope s, SyncedWriter w) =>
      MealPlanRepository(
        db,
        scope: s,
        writer: w,
        shopping: ShoppingRepository(db, scope: s, writer: w),
        clock: () => DateTime.utc(2026, 11, 2, 9),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    writer = FailingWriter(db, accountId: 'one');
    repo = makeRepo(scope, writer);
    await db
        .into(db.recipes)
        .insert(
          RecipesCompanion.insert(
            id: 'r1',
            title: 'Pasulj',
            servings: 4,
            source: 'manual',
            ingredientsJson: '[]',
            stepsJson: '[]',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            householdId: const Value('home-one'),
          ),
        );
  });

  tearDown(() => db.close());

  Future<List<String>> outboxEntities() async => [
    for (final r in await (db.select(
      db.syncOutbox,
    )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get())
      r.entity,
  ];

  test('odobren nacrt čuva plan, obroke sa snimkom i porcijama, '
      'nabavku i outbox redom roditelj pa dete', () async {
    final id = await repo.approve(draft());

    final plan = (await repo.watchPlans().first).single;
    expect(plan.id, id);
    expect(plan.range, DateRange(monday, monday.addDays(2)));
    expect(plan.mealTypes, {MealType.lunch});
    expect(plan.defaultServings, 2);

    final meals = await repo.watchMeals(id).first;
    expect(meals.length, 3);
    expect(meals.first.slot, MealSlot(monday, MealType.lunch));
    expect(meals.first.recipeId, 'r1');
    expect(meals.first.snapshot!.title, 'Pasulj');
    expect(meals[1].recipeId, isNotNull, reason: 'nov recept ide u Recepte');
    expect(meals[1].snapshot!.ingredients.single.name, 'krompir');
    expect(meals.every((m) => m.servings == 2), isTrue);

    // Svaki obrok: 1 kg za 4 porcije → 0,5 kg za 2; tri obroka.
    final totals = await ShoppingRepository(
      db,
      scope: scope,
      writer: writer,
    ).planTotals(id);
    expect(totals.single.baseUnit, 'g');
    expect(totals.single.openMicros, toMicros(1500));

    final entities = await outboxEntities();
    expect(entities.first, 'meal_plan');
    expect(
      entities.indexOf('meal_plan_entry'),
      lessThan(entities.indexOf('shopping_source')),
    );
    expect(entities.where((e) => e == 'meal_plan_entry').length, 3);
    expect(entities.where((e) => e == 'recipe').length, 2);
    expect(
      entities.lastIndexOf('recipe'),
      lessThan(entities.indexOf('meal_plan_entry')),
    );

    // Novi recepti su u Recepti (sažetak bez koraka), povezani sa obrokom.
    final saved = await (db.select(
      db.recipes,
    )..where((t) => t.id.isNotIn(['r1']))).get();
    expect(saved.map((r) => r.id).toSet(), {
      meals[1].recipeId,
      meals[2].recipeId,
    });
    expect(saved.every((r) => r.source == 'ai'), isTrue);
    expect(saved.every((r) => r.householdId == 'home-one'), isTrue);
    expect(saved.every((r) => r.stepsJson == '[]'), isTrue);
  });

  test('nepotpun nacrt se ne čuva bez izričitog "nepotpun plan"', () async {
    final partial = draft(ready: 1);

    await expectLater(
      repo.approve(partial),
      throwsA(isA<IncompleteDraftException>()),
    );
    expect(await db.select(db.mealPlans).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);

    final id = await repo.approve(partial, allowPartial: true);
    final meals = await repo.watchMeals(id).first;
    expect(meals.map((m) => m.slot.date.day), [2, 3]);
    final plan = (await repo.watchPlans().first).single;
    expect(plan.slots.length, 3, reason: 'prazno mesto ostaje vidljivo');
  });

  test('nacrt bez ijednog spremnog obroka se ne čuva ni kao '
      'nepotpun', () async {
    final empty = PlanDraft(request: draft().request);
    await expectLater(
      repo.approve(empty, allowPartial: true),
      throwsA(isA<IncompleteDraftException>()),
    );
  });

  test('kvar usred čuvanja ne ostavlja ništa: ni plan, ni obroke, ni '
      'nabavku, ni outbox', () async {
    writer.failAt = 3;

    await expectLater(repo.approve(draft()), throwsStateError);

    expect(await db.select(db.mealPlans).get(), isEmpty);
    expect(await db.select(db.recipes).get(), hasLength(1));
    expect(await db.select(db.mealPlanEntries).get(), isEmpty);
    expect(await db.select(db.shoppingSources).get(), isEmpty);
    expect(await db.select(db.shoppingItems).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });

  test('odbačen nacrt ne menja ništa', () async {
    final before = await db.select(db.recipes).get();
    draft(); // nacrt postoji samo u memoriji
    expect(await db.select(db.mealPlans).get(), isEmpty);
    expect(await db.select(db.recipes).get(), before);
  });

  test('recept iz biblioteke obrisan pre odobrenja: obrok čuva snimak '
      'bez veze ka receptu', () async {
    await db.delete(db.recipes).go();

    final id = await repo.approve(draft());

    final first = (await repo.watchMeals(id).first).first;
    expect(first.recipeId, isNull);
    expect(first.snapshot!.title, 'Pasulj');
  });

  group('zastareo nacrt', () {
    test('plan promenjen posle početka nacrta se ne prepisuje', () async {
      final id = await repo.approve(draft(days: 2));
      final base = PlanBase(
        planId: id,
        fingerprint: await repo.fingerprint(id),
      );
      final meals = await repo.watchMeals(id).first;
      await (db.update(db.mealPlanEntries)
            ..where((t) => t.id.equals(meals.last.id)))
          .write(const MealPlanEntriesCompanion(servings: Value(5)));
      final outbox = (await db.select(db.syncOutbox).get()).length;

      await expectLater(
        repo.approve(draft(days: 2, base: base)),
        throwsA(isA<StaleDraftException>()),
      );
      expect((await repo.watchMeals(id).first).last.servings, 5);
      expect((await db.select(db.syncOutbox).get()).length, outbox);
    });

    test('nepromenjen plan: odobrenje menja obroke istog plana na '
        'istim mestima', () async {
      final id = await repo.approve(draft(days: 2));
      final before = await repo.watchMeals(id).first;
      final base = PlanBase(
        planId: id,
        fingerprint: await repo.fingerprint(id),
      );
      final next = draft(days: 2, base: base);
      final changed = next.copyWith(
        proposals: {
          ...next.proposals,
          next.request.slots.last: const SlotProposal(
            title: 'Gulaš',
            draftRecipeKey: 'gulaš',
          ),
        },
        newRecipes: {...next.newRecipes, 'gulaš': snapshot('Gulaš', kg: 2)},
      );

      expect(await repo.approve(changed), id);

      final after = await repo.watchMeals(id).first;
      expect(after.map((m) => m.id), before.map((m) => m.id));
      expect(after.last.snapshot!.title, 'Gulaš');
      expect(await db.select(db.mealPlans).get(), hasLength(1));
    });

    test('zaključan ili skuvan obrok se ne menja; takav nacrt je '
        'zastareo', () async {
      final id = await repo.approve(draft(days: 2));
      final meals = await repo.watchMeals(id).first;
      await (db.update(db.mealPlanEntries)
            ..where((t) => t.id.equals(meals.first.id)))
          .write(const MealPlanEntriesCompanion(isLocked: Value(true)));
      final base = PlanBase(
        planId: id,
        fingerprint: await repo.fingerprint(id),
      );

      await expectLater(
        repo.approve(draft(days: 2, base: base)),
        throwsA(isA<StaleDraftException>()),
      );
    });

    test('tuđi plan je zastareo, ne prepisuje se', () async {
      final id = await repo.approve(draft(days: 2));
      final fp = await repo.fingerprint(id);
      final other = makeRepo(
        const AccountScope(userId: 'two', householdId: 'home-two'),
        SyncedWriter(db, accountId: 'two'),
      );

      await expectLater(
        other.approve(
          draft(
            days: 2,
            base: PlanBase(planId: id, fingerprint: fp),
          ),
        ),
        throwsA(isA<StaleDraftException>()),
      );
      expect(await other.watchPlans().first, isEmpty);
    });
  });

  test('planovi su odvojeni po domaćinstvu', () async {
    final first = await repo.approve(draft());
    final second = await repo.approve(draft(days: 2));
    final other = makeRepo(
      const AccountScope(userId: 'two', householdId: 'home-two'),
      SyncedWriter(db, accountId: 'two'),
    );

    expect(await other.watchPlans().first, isEmpty);
    expect(await other.watchMeals(first).first, isEmpty);
    final ids = [for (final p in await repo.watchPlans().first) p.id];
    expect(ids.toSet(), {first, second});
  });

  test('datum obroka ne zavisi od vremenske zone uređaja', () async {
    final id = await repo.approve(draft(days: 1));
    final row = await db.select(db.mealPlanEntries).getSingle();
    expect(row.date.toUtc(), DateTime.utc(2026, 11, 2));
    expect((await repo.watchMeals(id).first).single.slot.date, monday);
    expect(
      jsonDecode(row.recipeSnapshotJson!),
      containsPair('title', 'Pasulj'),
    );
  });

  test('predlog vidi samo potvrđenu zalihu svog domaćinstva', () async {
    Future<void> pantry(
      String id,
      String name, {
      bool confirmed = true,
      String home = 'home-one',
    }) => db
        .into(db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            id: id,
            name: name,
            category: 'ostalo',
            addedAt: DateTime.utc(2026),
            householdId: Value(home),
            confirmedAt: Value(confirmed ? DateTime.utc(2026) : null),
          ),
        );
    await pantry('a', 'pirinač');
    await pantry('b', 'brašno', confirmed: false);
    await pantry('c', 'šećer', home: 'home-two');

    expect(await repo.confirmedPantryNames(), ['pirinač']);
  });

  test('isti nov recept na više mesta je jedan recept u Receptima', () async {
    final base = draft(days: 3);
    final same = base.copyWith(
      proposals: {
        for (final s in base.request.slots)
          s: const SlotProposal(title: 'Sarma', draftRecipeKey: 'sarma'),
      },
      newRecipes: {'sarma': snapshot('Sarma')},
    );

    final id = await repo.approve(same);

    final meals = await repo.watchMeals(id).first;
    expect(meals.map((m) => m.recipeId).toSet(), hasLength(1));
    final titles = [for (final r in await db.select(db.recipes).get()) r.title];
    expect(titles.where((t) => t == 'Sarma'), hasLength(1));
  });
}
