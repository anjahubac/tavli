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
import 'package:tavli/sync/synced_writer.dart';

const scope = AccountScope(userId: 'one', householdId: 'home-one');

/// Sreda, 4. novembar 2026.
final today = CivilDate(2026, 11, 4);

Recipe recipe(String id, String title, {double kg = 1}) => Recipe(
  id: id,
  title: title,
  servings: 4,
  source: RecipeSource.manual,
  createdAt: DateTime.utc(2026),
  ingredients: [Ingredient(name: 'krompir', quantity: kg, unit: 'kg')],
);

void main() {
  late AppDatabase db;
  late MealPlanRepository repo;
  late ShoppingRepository shop;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final writer = SyncedWriter(db, accountId: 'one');
    shop = ShoppingRepository(db, scope: scope, writer: writer);
    repo = MealPlanRepository(
      db,
      scope: scope,
      writer: writer,
      shopping: shop,
      clock: () => DateTime.utc(2026, 11, 4, 9),
    );
    for (final r in [recipe('musaka', 'Musaka'), recipe('pasulj', 'Pasulj')]) {
      await db
          .into(db.recipes)
          .insert(
            RecipesCompanion.insert(
              id: r.id,
              title: r.title,
              servings: r.servings,
              source: 'manual',
              ingredientsJson: '[]',
              stepsJson: '[]',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              householdId: const Value('home-one'),
            ),
          );
    }
  });

  tearDown(() => db.close());

  Future<List<String>> outbox() async => [
    for (final r in await db.select(db.syncOutbox).get()) r.entity,
  ];

  Future<int> open(String planId) async =>
      (await shop.planTotals(planId))
          .fold<int>(0, (sum, t) => sum + t.openMicros);

  final lunch = MealSlot(today, MealType.lunch);

  test('bez plana: pravi plan za slobodne dane nedelje od danas, upisuje '
      'obrok sa snimkom i porcijama i puni nabavku', () async {
    final planId = await repo.addRecipe(
      recipe: recipe('musaka', 'Musaka'),
      slot: lunch,
      servings: 2,
    );

    final plan = (await repo.watchPlan(planId).first)!;
    // Od srede (danas) do nedelje: prošli dani se ne dodaju.
    expect(plan.range, DateRange(today, CivilDate(2026, 11, 8)));
    expect(plan.mealTypes, {MealType.lunch});
    final meals = await repo.meals(planId);
    expect(meals, hasLength(1));
    expect(meals.single.slot, lunch);
    expect(meals.single.recipeId, 'musaka');
    expect(meals.single.servings, 2);
    expect(meals.single.snapshot?.title, 'Musaka');
    // 1 kg za 4 porcije, 2 porcije: 0,5 kg.
    expect(await open(planId), toMicros(500));
    expect(await outbox(), containsAll(['meal_plan', 'meal_plan_entry']));
  });

  test('postojeći plan za taj dan dobija obrok; nova vrsta obroka se '
      'dodaje planu', () async {
    final first = await repo.addRecipe(
      recipe: recipe('pasulj', 'Pasulj'),
      slot: lunch,
      servings: 4,
    );
    final second = await repo.addRecipe(
      recipe: recipe('musaka', 'Musaka'),
      slot: MealSlot(today.addDays(1), MealType.dinner),
      servings: 4,
    );

    expect(second, first);
    final plan = (await repo.watchPlan(first).first)!;
    expect(plan.mealTypes, {MealType.lunch, MealType.dinner});
    expect(await repo.meals(first), hasLength(2));
  });

  test('zauzeto mesto traži izričitu zamenu; zamena menja recept, porcije '
      'i nabavku istog obroka', () async {
    final planId = await repo.addRecipe(
      recipe: recipe('pasulj', 'Pasulj'),
      slot: lunch,
      servings: 4,
    );
    final before = (await repo.meals(planId)).single;

    await expectLater(
      repo.addRecipe(
        recipe: recipe('musaka', 'Musaka', kg: 2),
        slot: lunch,
        servings: 2,
      ),
      throwsA(isA<SlotTakenException>()),
    );
    expect((await repo.meals(planId)).single.recipeId, 'pasulj');

    await repo.addRecipe(
      recipe: recipe('musaka', 'Musaka', kg: 2),
      slot: lunch,
      servings: 2,
      replace: true,
    );
    final after = (await repo.meals(planId)).single;
    expect(after.id, before.id);
    expect(after.recipeId, 'musaka');
    expect(after.servings, 2);
    expect(await open(planId), toMicros(1000));
  });

  test('skuvan ili zaključan obrok se ne menja ni uz zamenu', () async {
    final planId = await repo.addRecipe(
      recipe: recipe('pasulj', 'Pasulj'),
      slot: lunch,
      servings: 4,
    );
    final meal = (await repo.meals(planId)).single;

    await repo.setCooked(meal.id, cooked: true);
    await expectLater(
      repo.addRecipe(
        recipe: recipe('musaka', 'Musaka'),
        slot: lunch,
        servings: 4,
        replace: true,
      ),
      throwsA(isA<ProtectedMealException>()),
    );

    await repo.setCooked(meal.id, cooked: false);
    await repo.setLocked(meal.id, locked: true);
    await expectLater(
      repo.addRecipe(
        recipe: recipe('musaka', 'Musaka'),
        slot: lunch,
        servings: 4,
        replace: true,
      ),
      throwsA(isA<ProtectedMealException>()),
    );
    expect((await repo.meals(planId)).single.recipeId, 'pasulj');
  });

  test('prošao dan i porcije van 1–20 se odbijaju bez upisa', () async {
    await expectLater(
      repo.addRecipe(
        recipe: recipe('musaka', 'Musaka'),
        slot: MealSlot(today.addDays(-1), MealType.lunch),
        servings: 2,
      ),
      throwsA(isA<ProtectedMealException>()),
    );
    expect(
      () => repo.addRecipe(
        recipe: recipe('musaka', 'Musaka'),
        slot: lunch,
        servings: 21,
      ),
      throwsArgumentError,
    );
    expect(await repo.watchPlans().first, isEmpty);
    expect(await outbox(), isEmpty);
  });

  test(
    'mealsIn vraća obroke po mestu iz plana koji važi za svaki dan',
    () async {
      await repo.addRecipe(
        recipe: recipe('pasulj', 'Pasulj'),
        slot: lunch,
        servings: 4,
      );
      final week = weekOf(today);
      final slots = await repo.mealsIn(week);

      expect(slots.keys, [lunch]);
      expect(slots[lunch]!.snapshot?.title, 'Pasulj');
      expect(await repo.mealsIn(weekOf(today.addDays(7))), isEmpty);
    },
  );

  group('freeWeekAround', () {
    MealPlan plan(CivilDate start, CivilDate end) => MealPlan(
      id: 'p',
      range: DateRange(start, end),
      mealTypes: const {MealType.lunch},
      defaultServings: 2,
      usePantry: true,
      createdAt: DateTime.utc(2026),
    );

    test('ne preklapa postojeći plan ni prošle dane', () {
      // Plan pokriva petak i subotu; dan je sreda, danas je sreda.
      final r = freeWeekAround(today, today, [
        plan(CivilDate(2026, 11, 6), CivilDate(2026, 11, 7)),
      ]);
      expect(r, DateRange(today, CivilDate(2026, 11, 5)));
    });

    test('budući dan u drugoj nedelji uzima celu tu nedelju', () {
      final day = CivilDate(2026, 11, 12);
      expect(
        freeWeekAround(day, today, const []),
        DateRange(CivilDate(2026, 11, 9), CivilDate(2026, 11, 15)),
      );
    });
  });
}
