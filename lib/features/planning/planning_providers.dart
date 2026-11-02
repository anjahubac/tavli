import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/auth_controller.dart';
import '../../data/meal_plan_repository.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../providers.dart';
import '../recipes/recipe_providers.dart';

/// Planovi prijavljenog domaćinstva (čita lokalni keš naloga).
final mealPlanRepositoryProvider = Provider<MealPlanRepository>(
  (ref) => MealPlanRepository(
    ref.watch(databaseProvider),
    scope: ref.watch(accountScopeProvider) ?? noAccountScope,
    writer: ref.watch(syncedWriterProvider),
    shopping: ref.watch(shoppingRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Svi sačuvani planovi, noviji prvi.
final mealPlansProvider = StreamProvider.autoDispose<List<MealPlan>>(
  (ref) => ref.watch(mealPlanRepositoryProvider).watchPlans(),
);

final mealPlanProvider = StreamProvider.autoDispose.family<MealPlan?, String>(
  (ref, id) => ref.watch(mealPlanRepositoryProvider).watchPlan(id),
);

final plannedMealsProvider = StreamProvider.autoDispose
    .family<List<PlannedMeal>, String>(
      (ref, id) => ref.watch(mealPlanRepositoryProvider).watchMeals(id),
    );

/// Plan koji se prikazuje: najnoviji koji sadrži danas, inače najnoviji.
MealPlan? selectDefaultPlan(List<MealPlan> plans, DateTime now) {
  final today = CivilDate.today(() => now);
  for (final p in plans) {
    if (p.range.contains(today)) return p;
  }
  return plans.isEmpty ? null : plans.first;
}
