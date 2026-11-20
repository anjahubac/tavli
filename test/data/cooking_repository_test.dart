import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/cooking_repository.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/pantry_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/cooked_event.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/sync/synced_writer.dart';

const scope = AccountScope(userId: 'ana', householdId: 'home-one');

/// Beleži pozive; [fail] baca grešku pri kuvanju.
class RecordingEffect implements CookedEffect {
  final cooked = <String>[];
  final undone = <String>[];
  bool fail = false;

  @override
  Future<void> onCooked(CookedEvent event) async {
    if (fail) throw StateError('dnevnik nije upisan');
    cooked.add(event.id);
  }

  @override
  Future<void> onUndone(CookedEvent event) async => undone.add(event.id);
}

final thursday = CivilDate(2026, 11, 19);

RecipeSnapshot palacinke() => const RecipeSnapshot(
  title: 'Palačinke',
  baseServings: 4,
  ingredients: [
    Ingredient(name: 'brašno', quantity: 250, unit: 'g'),
    Ingredient(name: 'mleko', quantity: 500, unit: 'ml'),
  ],
);

void main() {
  late AppDatabase db;
  late SyncedWriter writer;
  late MealPlanRepository plans;
  late PantryRepository pantry;
  late CookingRepository cooking;
  late RecordingEffect effect;
  late DateTime now;
  late List<PlannedMeal> meals;

  DateTime at(int hour) => DateTime.utc(2026, 11, 20, hour);

  CookingRepository makeCooking(AccountScope s, {List<CookedEffect>? effects}) {
    final w = SyncedWriter(db, accountId: s.userId);
    return CookingRepository(
      db,
      scope: s,
      writer: w,
      plans: MealPlanRepository(
        db,
        scope: s,
        writer: w,
        shopping: ShoppingRepository(db, scope: s, writer: w, clock: () => now),
        clock: () => now,
      ),
      effects: effects ?? const [],
      clock: () => now,
    );
  }

  Future<void> addPantry(
    String id,
    String name,
    double? quantity,
    String? unit,
  ) => db
      .into(db.pantryItems)
      .insert(
        PantryItemsCompanion.insert(
          id: id,
          name: name,
          quantity: Value(quantity),
          unit: Value(unit),
          category: 'ostalo',
          addedAt: at(9),
          confirmedAt: Value(at(9)),
          householdId: const Value('home-one'),
        ),
      );

  /// Dva ručka palačinki (20. i 21. novembar), 4 porcije svaki.
  Future<void> seedPlan() async {
    final request = PlanRequest(
      range: DateRange(CivilDate(2026, 11, 20), CivilDate(2026, 11, 21)),
      mealTypes: const {MealType.lunch},
      servings: 4,
    );
    final planId = await plans.approve(
      PlanDraft(
        request: request,
        proposals: {
          for (final s in request.slots)
            s: SlotProposal(
              title: 'Palačinke',
              draftRecipeKey: 'p${s.date.day}',
            ),
        },
        newRecipes: {
          for (final s in request.slots) 'p${s.date.day}': palacinke(),
        },
      ),
    );
    meals = await plans.watchMeals(planId).first;
  }

  Future<Map<String, double?>> available() => pantry.watchAvailable().first;

  Future<ShoppingSourceRow> sourceOf(String entryId) => (db.select(
    db.shoppingSources,
  )..where((t) => t.planEntryId.equals(entryId))).getSingle();

  setUp(() async {
    now = at(10);
    db = AppDatabase(NativeDatabase.memory());
    writer = SyncedWriter(db, accountId: scope.userId);
    final shopping = ShoppingRepository(
      db,
      scope: scope,
      writer: writer,
      clock: () => now,
    );
    plans = MealPlanRepository(
      db,
      scope: scope,
      writer: writer,
      shopping: shopping,
      clock: () => now,
    );
    pantry = PantryRepository(
      db,
      scope: scope,
      writer: writer,
      clock: () => now,
    );
    effect = RecordingEffect();
    cooking = CookingRepository(
      db,
      scope: scope,
      writer: writer,
      plans: plans,
      effects: [effect],
      clock: () => now,
    );
    await addPantry('brasno', 'brašno', 1000, 'g');
    await addPantry('mleko', 'mleko', null, null);
    await seedPlan();
  });

  tearDown(() => db.close());

  test('primer iz ugovora: ponovljeno skuvano, dvostruko poništavanje, '
      'ponovno kuvanje i ručno brojanje', () async {
    final meal = meals.first.id;

    now = at(12);
    final e1 = await cooking.markCooked(meal);
    expect(e1, isNotNull);
    expect((await available())['brasno'], 750);
    expect((await available())['mleko'], isNull);
    expect((await sourceOf(meal)).closedAt, isNotNull);

    // Ponovljen klik: isti zapis, bez nove potrošnje.
    expect((await cooking.markCooked(meal))!.id, e1!.id);
    expect(await db.select(db.cookedEvents).get(), hasLength(1));
    expect(await db.select(db.pantryConsumptions).get(), hasLength(1));
    expect((await available())['brasno'], 750);

    final undone = await cooking.undoCooked(meal);
    expect(undone!.id, e1.id);
    expect(undone.undoneAt, isNotNull);
    expect(undone.undoReason, UndoReason.user);
    expect((await available())['brasno'], 1000);
    expect((await sourceOf(meal)).closedAt, isNull);

    expect(await cooking.undoCooked(meal), isNull);
    expect((await available())['brasno'], 1000);

    now = at(13);
    final e2 = await cooking.markCooked(meal);
    expect(e2!.id, isNot(e1.id));
    expect((await available())['brasno'], 750);

    now = at(14);
    await pantry.setQuantity('brasno', 600);
    expect((await available())['brasno'], 600);

    // Brojanje posle kuvanja ima prednost: poništavanje ne vraća zalihu.
    now = at(15);
    await cooking.undoCooked(meal);
    expect((await available())['brasno'], 600);
    expect(
      (await plans.watchMeals(meals.first.planId).first).first.isCooked,
      isFalse,
    );
    expect(effect.cooked, [e1.id, e2.id]);
    expect(effect.undone, [e1.id, e2.id]);
  });

  test('kuvanje posle ručnog brojanja se oduzima i vraća normalno', () async {
    now = at(11);
    await pantry.setQuantity('brasno', 800);
    now = at(12);
    await cooking.markCooked(meals.first.id);
    expect((await available())['brasno'], 550);
    await cooking.undoCooked(meals.first.id);
    expect((await available())['brasno'], 800);
  });

  test('zapis čuva obrok, ko je kuvao i porcije; outbox šalje zapis pre '
      'potrošnje', () async {
    await db.delete(db.syncOutbox).go();
    final e = await cooking.markCooked(meals.first.id);

    expect(e!.actorUserId, 'ana');
    expect(e.servings, 4);
    expect(e.mealDate, CivilDate(2026, 11, 20));
    expect(e.mealType, MealType.lunch);
    final row = await db.select(db.cookedEvents).getSingle();
    expect(row.householdId, 'home-one');

    final entities = [
      for (final r in await (db.select(
        db.syncOutbox,
      )..orderBy([(t) => OrderingTerm.asc(t.seq)])).get())
        r.entity,
    ];
    expect(entities.indexOf('cooked_event'), 0);
    expect(
      entities.indexOf('pantry_consumption'),
      greaterThan(entities.indexOf('cooked_event')),
    );
    expect(entities, contains('meal_plan_entry'));
  });

  test('dva obroka iz iste stavke: drugi uzima samo ono što je ostalo, '
      'poništavanje vraća tačno njegov deo', () async {
    await pantry.setQuantity('brasno', 300);
    // Usklađivanje posle izmene ostave: drugi obrok sada ima samo 50 g.
    await plans.changeServings(meals.last.id, 4);

    now = at(12);
    await cooking.markCooked(meals.first.id);
    await cooking.markCooked(meals.last.id);
    expect((await available())['brasno'], 0);

    await cooking.undoCooked(meals.last.id);
    expect((await available())['brasno'], 50);
  });

  test('stavka bez količine i stavka druge jedinice se ne troše', () async {
    await (db.update(db.pantryItems)..where((t) => t.id.equals('brasno')))
        .write(const PantryItemsCompanion(unit: Value('kom')));
    await plans.changeServings(meals.first.id, 4);

    await cooking.markCooked(meals.first.id);

    expect(await db.select(db.pantryConsumptions).get(), isEmpty);
    expect((await available())['mleko'], isNull);
  });

  test('greška potrošača vraća celu operaciju', () async {
    await db.delete(db.syncOutbox).go();
    effect.fail = true;

    await expectLater(
      cooking.markCooked(meals.first.id),
      throwsA(isA<StateError>()),
    );

    expect(await db.select(db.cookedEvents).get(), isEmpty);
    expect(await db.select(db.pantryConsumptions).get(), isEmpty);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
    expect(
      (await plans.watchMeals(meals.first.planId).first).first.isCooked,
      isFalse,
    );
  });

  test('dva uređaja bez mreže: važi raniji zapis, potrošnja se računa '
      'jednom, poništavanje zatvara oba', () async {
    now = at(12);
    final mine = await cooking.markCooked(meals.first.id);
    // Stiže zapis drugog uređaja za isti obrok, skuvan malo kasnije.
    await db
        .into(db.cookedEvents)
        .insert(
          CookedEventsCompanion.insert(
            id: 'drugi-uredjaj',
            householdId: const Value('home-one'),
            planEntryId: meals.first.id,
            mealDate: CivilDate(2026, 11, 20).toWire(),
            mealType: 'lunch',
            actorUserId: 'marko',
            servings: 4,
            cookedAt: at(12).add(const Duration(minutes: 5)),
          ),
        );
    await db
        .into(db.pantryConsumptions)
        .insert(
          PantryConsumptionsCompanion.insert(
            id: 'potrosnja-2',
            householdId: const Value('home-one'),
            eventId: 'drugi-uredjaj',
            pantryItemId: 'brasno',
            baseUnit: 'g',
            micros: 250000000,
            createdAt: at(12),
          ),
        );

    expect((await cooking.watchActive(meals.first.id).first)!.id, mine!.id);
    expect((await available())['brasno'], 750);

    await cooking.undoCooked(meals.first.id);
    final rows = await db.select(db.cookedEvents).get();
    expect(rows.every((r) => r.undoneAt != null), isTrue);
    expect((await available())['brasno'], 1000);
    expect(await cooking.watchActive(meals.first.id).first, isNull);
    // Potrošač dobija oba zatvorena zapisa, važeći prvi.
    expect(effect.undone, [mine.id, 'drugi-uredjaj']);
  });

  test(
    'raspoloživa količina se osvežava uživo pri kuvanju i poništavanju',
    () async {
      final meal = meals.first.id;
      final values = <double?>[];
      final sub = pantry.watchAvailable().listen(
        (m) => values.add(m['brasno']),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(values.last, 1000);

      now = at(12);
      await cooking.markCooked(meal);
      await pumpEventQueue();
      expect(values.last, 750);

      await cooking.undoCooked(meal);
      await pumpEventQueue();
      expect(values.last, 1000);
    },
  );

  test('obrok skuvan pre ove verzije (bez zapisa): skuvano ništa ne menja, '
      'poništavanje samo skida oznaku', () async {
    await plans.setCooked(meals.first.id, cooked: true);

    expect(await cooking.markCooked(meals.first.id), isNull);
    expect(await db.select(db.cookedEvents).get(), isEmpty);

    expect(await cooking.undoCooked(meals.first.id), isNull);
    expect(
      (await plans.watchMeals(meals.first.planId).first).first.isCooked,
      isFalse,
    );
  });

  test('tuđe domaćinstvo ne može da označi obrok', () async {
    final other = makeCooking(
      const AccountScope(userId: 'b', householdId: 'home-two'),
    );
    await expectLater(
      other.markCooked(meals.first.id),
      throwsA(isA<MealNotFoundException>()),
    );
    await expectLater(
      other.undoCooked(meals.first.id),
      throwsA(isA<MealNotFoundException>()),
    );
    expect(await db.select(db.cookedEvents).get(), isEmpty);
  });

  group('raspoloživa količina', () {
    final cooked = {'e1': at(12), 'e2': at(13)};

    double? calc({
      double? quantity = 300,
      DateTime? setAt,
      Set<String>? counted,
    }) => availableQuantity(
      quantity: quantity,
      unit: 'g',
      quantitySetAt: setAt,
      consumptions: const [
        (eventId: 'e1', pantryItemId: 'o', micros: 250000000),
        (eventId: 'e2', pantryItemId: 'o', micros: 250000000),
      ],
      counted: counted ?? {'e1', 'e2'},
      cookedAt: cooked,
    );

    test('nikad ispod nule; poništavanje vraća tačno svoj deo', () {
      expect(calc(), 0);
      expect(calc(counted: {'e1'}), 50);
    });

    test('brojanje posle kuvanja briše ranije oduzimanje', () {
      expect(calc(setAt: at(12)), 50);
      expect(calc(setAt: at(14)), 300);
    });

    test('kilogrami: potrošnja u gramima', () {
      expect(
        availableQuantity(
          quantity: 1,
          unit: 'kg',
          quantitySetAt: null,
          consumptions: const [
            (eventId: 'e1', pantryItemId: 'o', micros: 250000000),
          ],
          counted: {'e1'},
          cookedAt: cooked,
        ),
        0.75,
      );
    });

    test('nepoznata količina ostaje nepoznata', () {
      expect(calc(quantity: null), isNull);
    });
  });
}
