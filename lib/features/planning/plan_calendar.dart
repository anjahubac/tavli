import 'package:material_ui/material_ui.dart';

import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import 'plan_format.dart';

const _weekdayShort = ['Po', 'Ut', 'Sr', 'Če', 'Pe', 'Su', 'Ne'];

/// Mali mesečni pregled plana: nedelje pon–ned, dani plana sa brojem
/// planiranih obroka. Dodir bira dan; detalji nedelje su ispod kalendara.
class PlanMonthCalendar extends StatelessWidget {
  const PlanMonthCalendar({
    super.key,
    required this.plan,
    required this.meals,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final MealPlan plan;
  final List<PlannedMeal> meals;
  final CivilDate selected;
  final CivilDate today;
  final ValueChanged<CivilDate> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final perDay = <CivilDate, int>{};
    for (final m in meals) {
      perDay[m.slot.date] = (perDay[m.slot.date] ?? 0) + 1;
    }
    final first = weekOf(plan.range.start).start;
    final weeks = (first.daysUntil(weekOf(plan.range.end).end) + 1) ~/ 7;
    final selectedWeek = weekOf(selected);

    Widget cell(CivilDate d) {
      if (!plan.range.contains(d)) return const SizedBox(height: 48);
      final count = perDay[d] ?? 0;
      final isSelected = d == selected;
      final isToday = d == today;
      return Semantics(
        button: true,
        selected: isSelected,
        label:
            '${dayLabel(d)}, ${mealsCount(count)}${isToday ? ', danas' : ''}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onSelect(d),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : selectedWeek.contains(d)
                  ? colors.secondaryContainer
                  : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: colors.primary, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${d.day}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSelected ? colors.onPrimary : null,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < count && i < 3; i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? colors.onPrimary : colors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdayShort)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weeks; w++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: cell(first.addDays(w * 7 + d)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
