import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/meal_plan.dart';
import '../../domain/recipe_format.dart';

/// Naziv jela iz snimka plana.
String mealTitle(PlannedMeal? meal) => meal == null
    ? 'Nije planirano'
    : (meal.snapshot?.title ?? 'Recept nije dostupan');

/// Vreme, porcije i zaključavanje: „40 min · 2 porcije · zaključano“.
String mealDetail(PlannedMeal meal) => [
  if (meal.snapshot?.prepMinutes case final m?) '$m min',
  servingsLabel(meal.servings),
  if (meal.isLocked) 'zaključano',
].join(' · ');

/// Jedno mesto u planu kao [TavliMealCard]: vrsta obroka, jelo i detalji;
/// skuvano je zasenčeno. Prazno mesto („Nije planirano“) se ne otvara.
class MealEntryCard extends StatelessWidget {
  const MealEntryCard({
    super.key,
    required this.slot,
    required this.meal,
    required this.onTap,
    this.compact = false,
  });

  final MealSlot slot;
  final PlannedMeal? meal;
  final ValueChanged<PlannedMeal> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meal = this.meal;
    return TavliMealCard(
      compact: compact,
      label: slot.type.label,
      title: mealTitle(meal),
      detail: meal == null ? null : mealDetail(meal),
      cooked: meal?.isCooked ?? false,
      muted: meal == null,
      onTap: meal == null ? null : () => onTap(meal),
    );
  }
}

/// Red obroka u listi ispod mesečnog kalendara.
TavliMealRow mealRow(
  MealSlot slot,
  PlannedMeal? meal, {
  required ValueChanged<PlannedMeal> onTap,
}) => TavliMealRow(
  label: slot.type.label,
  title: mealTitle(meal),
  cooked: meal?.isCooked ?? false,
  muted: meal == null,
  onTap: meal == null ? null : () => onTap(meal),
);
