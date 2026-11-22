import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Scrollable;
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/features/shopping/shopping_providers.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';
import 'shopping_screen_test.dart'
    show pumpShopping, scopeOf, tapIn, tileOf, today;

const _pantryId = 'fixture-kupus';
const _name = 'kupus';

Future<void> _seedPlanAndPantry(
  AppDatabase db, {
  required bool wholePlan,
}) async {
  final scope = await scopeOf(db);
  final writer = SyncedWriter(db, accountId: scope.userId);
  final time = today.toUtc();
  await db
      .into(db.pantryItems)
      .insert(
        PantryItemsCompanion.insert(
          id: _pantryId,
          name: _name,
          quantity: const Value(100),
          unit: const Value('g'),
          category: 'voće i povrće',
          addedAt: time,
          confirmedAt: Value(time),
          householdId: Value(scope.householdId),
        ),
      );

  final plans = MealPlanRepository(
    db,
    scope: scope,
    writer: writer,
    shopping: ShoppingRepository(db, scope: scope, writer: writer),
    clock: () => time,
  );
  final day = CivilDate(today.year, today.month, today.day);
  final request = PlanRequest(
    range: DateRange(day, wholePlan ? day.addDays(7) : day),
    mealTypes: const {MealType.lunch},
  );
  await plans.approve(
    PlanDraft(
      request: request,
      proposals: {
        request.slots.first: const SlotProposal(
          title: 'Ručak sa kupusom',
          draftRecipeKey: 'fixture-recipe',
        ),
      },
      newRecipes: const {
        'fixture-recipe': RecipeSnapshot(
          title: 'Ručak sa kupusom',
          baseServings: 2,
          ingredients: [
            Ingredient(
              name: _name,
              quantity: 300,
              unit: 'g',
              category: 'voće i povrće',
            ),
          ],
        ),
      },
    ),
    allowPartial: wholePlan,
  );
}

void main() {
  for (final wholePlan in [false, true]) {
    final view = wholePlan ? 'Ceo plan' : 'Nedelja';
    testTavli('$view se osvežava kad količina u ostavi postane nepoznata', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await pumpShopping(
        tester,
        size: const Size(320, 760),
        setup: (db) => _seedPlanAndPantry(db, wholePlan: wholePlan),
      );
      if (wholePlan) await tapIn(tester, find.text('Ceo plan'));
      await tester.scrollUntilVisible(
        find.text(_name),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      final row = tileOf(_name);
      expect(tester.widget<TavliCheckRow>(row).detail, '200 g');

      final container = ProviderScope.containerOf(tester.element(row));
      await container
          .read(pantryRepositoryProvider)
          .setQuantity(_pantryId, null);
      await tester.pumpAndSettle();

      final pantryItem = await app.db.select(app.db.pantryItems).getSingle();
      expect(pantryItem.quantity, isNull);
      expect(pantryItem.confirmedAt, isNotNull);
      expect(tester.widget<TavliCheckRow>(row).detail, '300 g');
      expect(
        find.descendant(of: row, matching: find.text('Imaš u ostavi, proveri')),
        findsOneWidget,
      );

      await container
          .read(pantryRepositoryProvider)
          .setQuantity(_pantryId, 100);
      await tester.pumpAndSettle();
      expect(tester.widget<TavliCheckRow>(row).detail, '200 g');
      expect(find.text('Imaš u ostavi, proveri'), findsNothing);
    });
  }
}
