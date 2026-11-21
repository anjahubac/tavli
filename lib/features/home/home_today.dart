import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../planning/planning_providers.dart';
import '../recipes/recipe_providers.dart' show clockProvider;

/// Šta Početna prikazuje za danas i sutra. Samo pogled na odobren plan,
/// nije posebno skladište (021 FR-008).
class HomeDay {
  const HomeDay({
    required this.date,
    required this.hasPlans,
    this.today = const [],
    this.tomorrow = const [],
  });

  final CivilDate date;

  /// Domaćinstvo ima bar jedan sačuvan plan (bez plana: „Napravi plan“).
  final bool hasPlans;

  /// Današnji obroci, redom u danu.
  final List<PlannedMeal> today;

  /// Sutrašnji obroci, redom u danu.
  final List<PlannedMeal> tomorrow;

  /// Prvi neskuvan današnji obrok; null kad danas nema obroka ili su svi
  /// skuvani.
  PlannedMeal? get next {
    for (final m in today) {
      if (!m.isCooked) return m;
    }
    return null;
  }

  bool get allCooked => today.isNotEmpty && next == null;
}

/// Plan za dan: najnoviji koji ga sadrži ([plans] su noviji prvi, kao u
/// `MealPlanRepository.watchPlans`).
MealPlan? planForDay(List<MealPlan> plans, CivilDate day) {
  for (final p in plans) {
    if (p.range.contains(day)) return p;
  }
  return null;
}

/// Obroci jednog dana, redom u danu.
List<PlannedMeal> mealsOn(List<PlannedMeal> meals, CivilDate day) => [
  for (final m in meals)
    if (m.slot.date == day) m,
]..sort((a, b) => a.slot.compareTo(b.slot));

/// Danas i sutra na Početnoj. Greška čitanja plana ili obroka je greška
/// (ne prazno stanje), a učitavanje traje dok ne stignu svi potrebni podaci.
final homeDayProvider = Provider.autoDispose<AsyncValue<HomeDay>>((ref) {
  final date = CivilDate.today(ref.watch(clockProvider));
  final tomorrowDate = date.addDays(1);
  final plansAsync = ref.watch(mealPlansProvider);
  if (plansAsync.hasError) {
    return AsyncError(plansAsync.error!, plansAsync.stackTrace!);
  }
  final plans = plansAsync.value;
  if (plans == null) return const AsyncLoading();

  AsyncValue<List<PlannedMeal>> mealsFor(CivilDate day) {
    final plan = planForDay(plans, day);
    if (plan == null) return const AsyncData([]);
    return ref
        .watch(plannedMealsProvider(plan.id))
        .whenData((meals) => mealsOn(meals, day));
  }

  final today = mealsFor(date);
  final tomorrow = mealsFor(tomorrowDate);
  for (final a in [today, tomorrow]) {
    if (a.hasError) return AsyncError(a.error!, a.stackTrace!);
  }
  final (t, s) = (today.value, tomorrow.value);
  if (t == null || s == null) return const AsyncLoading();
  return AsyncData(
    HomeDay(date: date, hasPlans: plans.isNotEmpty, today: t, tomorrow: s),
  );
});
