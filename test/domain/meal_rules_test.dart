import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/meal_rules.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe_labels.dart';
import 'package:tavli/domain/shopping_source.dart';

final monday = CivilDate(2026, 11, 2);

MealSlot slot(int day, MealType type) => MealSlot(monday.addDays(day), type);

MealFacts dish(String key, [DishWeight? weight, DishKind? kind]) =>
    MealFacts(recipeKey: key, weight: weight, dishKind: kind);

void main() {
  group('pravila mesta', () {
    test('ručak lagan, večera jaka i teška užina krše pravilo', () {
      expect(slotRuleBreaks(MealType.lunch, dish('a', DishWeight.light)), {
        MealRule.lunchTooLight,
      });
      expect(slotRuleBreaks(MealType.dinner, dish('a', DishWeight.hearty)), {
        MealRule.dinnerTooHeavy,
      });
      expect(
        slotRuleBreaks(
          MealType.afternoonSnack,
          dish('a', DishWeight.medium, DishKind.soup),
        ),
        {MealRule.snackNotLight, MealRule.snackCooked},
      );
      expect(
        slotRuleBreaks(
          MealType.morningSnack,
          dish('a', DishWeight.light, DishKind.cooked),
        ),
        {MealRule.snackCooked},
      );
    });

    test('dozvoljeno: srednji ručak, testenina, srednja večera', () {
      expect(
        slotRuleBreaks(
          MealType.lunch,
          dish('a', DishWeight.medium, DishKind.pasta),
        ),
        isEmpty,
      );
      expect(
        slotRuleBreaks(MealType.dinner, dish('a', DishWeight.medium)),
        isEmpty,
      );
      expect(
        slotRuleBreaks(MealType.breakfast, dish('a', DishWeight.hearty)),
        isEmpty,
      );
    });

    test('nepoznata oznaka nije greška', () {
      for (final t in MealType.values) {
        expect(slotRuleBreaks(t, dish('a')), isEmpty, reason: t.name);
      }
    });
  });

  group('pravila plana', () {
    test('dva jaka obroka: krši onaj koji nije ručak', () {
      final breaks = mealRuleBreaks({
        slot(0, MealType.breakfast): dish('a', DishWeight.hearty),
        slot(0, MealType.lunch): dish('b', DishWeight.hearty),
      });
      expect(breaks, {
        slot(0, MealType.breakfast): {MealRule.secondHearty},
      });
    });

    test('jak obrok u različite dane je u redu', () {
      final breaks = mealRuleBreaks({
        slot(0, MealType.lunch): dish('a', DishWeight.hearty),
        slot(1, MealType.lunch): dish('b', DishWeight.hearty),
      });
      expect(breaks, isEmpty);
    });

    test('isti recept u 3 dana krši pravilo, posle toga ne', () {
      expect(
        mealRuleBreaks({
          slot(0, MealType.lunch): dish('sarma'),
          slot(2, MealType.lunch): dish('sarma'),
        }),
        {
          slot(2, MealType.lunch): {MealRule.repeated},
        },
      );
      expect(
        mealRuleBreaks({
          slot(0, MealType.lunch): dish('sarma'),
          slot(3, MealType.lunch): dish('sarma'),
        }),
        isEmpty,
      );
      expect(
        mealRuleBreaks({
          slot(0, MealType.lunch): dish('sarma'),
          slot(0, MealType.dinner): dish('sarma'),
        }),
        {
          slot(0, MealType.dinner): {MealRule.repeated},
        },
      );
    });
  });

  group('zamena ručka i večere', () {
    test('lagan ručak i jaka večera menjaju mesta', () {
      final meals = {
        slot(0, MealType.lunch): dish('salata', DishWeight.light),
        slot(0, MealType.dinner): dish('sarma', DishWeight.hearty),
      };
      expect(lunchDinnerSwaps(meals, meals.keys.toSet()), [
        (slot(0, MealType.lunch), slot(0, MealType.dinner)),
      ]);
    });

    test('bez zamene kad je ne popravlja ili mesto ne sme da se menja', () {
      final bothHearty = {
        slot(0, MealType.lunch): dish('a', DishWeight.hearty),
        slot(0, MealType.dinner): dish('b', DishWeight.hearty),
      };
      expect(lunchDinnerSwaps(bothHearty, bothHearty.keys.toSet()), isEmpty);

      final mixed = {
        slot(0, MealType.lunch): dish('salata', DishWeight.light),
        slot(0, MealType.dinner): dish('sarma', DishWeight.hearty),
      };
      expect(lunchDinnerSwaps(mixed, {slot(0, MealType.dinner)}), isEmpty);
    });
  });

  test('jela iz sačuvanog plana uzimaju oznake iz biblioteke', () {
    final facts = plannedMealFacts(
      [
        PlannedMeal(
          id: 'm1',
          planId: 'p',
          slot: slot(0, MealType.lunch),
          servings: 2,
          recipeId: 'r1',
          snapshot: const RecipeSnapshot(
            title: 'Pasulj',
            baseServings: 4,
            ingredients: [],
          ),
        ),
        PlannedMeal(
          id: 'm2',
          planId: 'p',
          slot: slot(1, MealType.lunch),
          servings: 2,
          snapshot: const RecipeSnapshot(
            title: 'Sarma',
            baseServings: 4,
            ingredients: [],
          ),
        ),
      ],
      {
        'r1': const RecipeLabels(
          weight: 'hearty',
          dishKind: 'cooked',
          source: 'user',
        ),
      },
    );
    expect(
      facts[slot(0, MealType.lunch)],
      const MealFacts(
        recipeKey: 'r1',
        title: 'Pasulj',
        weight: DishWeight.hearty,
        dishKind: DishKind.cooked,
      ),
    );
    expect(
      facts[slot(1, MealType.lunch)],
      const MealFacts(recipeKey: 'sarma', title: 'Sarma'),
    );
  });
}
