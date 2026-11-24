import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/meal_plan.dart';
import '../../providers.dart';
import 'home_today.dart';

sealed class HomeNotice {
  const HomeNotice();
}

class MissingShoppingNotice extends HomeNotice {
  const MissingShoppingNotice(this.meal);

  final PlannedMeal meal;
}

class PlanEndingNotice extends HomeNotice {
  const PlanEndingNotice();
}

Iterable<PlannedMeal> _upcomingMeals(HomeDay day) =>
    [...day.today, ...day.tomorrow].where((meal) => !meal.isCooked);

final _openMealShoppingProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) {
  final day = ref.watch(homeDayProvider).value;
  if (day == null) return Stream.value(const {});
  final ids = _upcomingMeals(day).map((meal) => meal.id).toList();
  if (ids.isEmpty) return Stream.value(const {});
  return ref.watch(shoppingRepositoryProvider).watchMealsWithOpenItems(ids);
});

/// Samo prvo primenljivo pravilo, po redosledu prioriteta.
final homeNoticeProvider = Provider.autoDispose<HomeNotice?>((ref) {
  final day = ref.watch(homeDayProvider).value;
  if (day == null) return null;

  final shopping = ref.watch(_openMealShoppingProvider);
  if (shopping.isLoading) return null;
  final missing = shopping.asData?.value ?? const <String>{};
  for (final meal in _upcomingMeals(day)) {
    if (missing.contains(meal.id)) return MissingShoppingNotice(meal);
  }

  return day.todayPlan?.endsSoonAfter(day.date) ?? false
      ? const PlanEndingNotice()
      : null;
});
