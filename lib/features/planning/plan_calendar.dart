import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import 'meal_entry_card.dart';
import 'plan_format.dart';

/// Šta čitač ekrana kaže za dan: „Sreda, 4. novembar, 3 obroka, danas“.
String daySemantics(CivilDate d, int meals, CivilDate today) =>
    '${dayLabel(d)}, ${mealsCount(meals)}${d == today ? ', danas' : ''}';

/// Mesec izabranog dana u kalendaru plana: za svaki dan jela redom obroka
/// (tačke na telefonu, nazivi na računaru). Biraju se samo dani plana.
class PlanMonthCalendar extends StatelessWidget {
  const PlanMonthCalendar({
    super.key,
    required this.plan,
    required this.meals,
    required this.selected,
    required this.today,
    required this.onSelect,
    this.detailed = false,
  });

  final MealPlan plan;
  final List<PlannedMeal> meals;
  final CivilDate selected;
  final CivilDate today;
  final ValueChanged<CivilDate> onSelect;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final perDay = <CivilDate, List<PlannedMeal>>{};
    for (final m in [...meals]..sort((a, b) => a.slot.compareTo(b.slot))) {
      (perDay[m.slot.date] ??= []).add(m);
    }
    final month = monthOf(selected);
    final first = weekOf(month.start).start;
    final count = first.daysUntil(weekOf(month.end).end) + 1;
    final dates = [for (var i = 0; i < count; i++) first.addDays(i)];
    return TavliMonthCalendar(
      weekdays: detailed ? weekdaysShort : weekdaysInitial,
      detailed: detailed,
      selectedIndex: dates.indexOf(selected),
      onSelected: (i) => onSelect(dates[i]),
      days: [
        for (final d in dates)
          TavliCalendarDay(
            day: '${d.day}',
            active: month.contains(d) && plan.range.contains(d),
            semanticLabel: daySemantics(d, perDay[d]?.length ?? 0, today),
            marks: [
              for (final m in perDay[d] ?? const <PlannedMeal>[])
                TavliCalendarMark(mealTitle(m), done: m.isCooked),
            ],
          ),
      ],
    );
  }
}

/// Nedelja izabranog dana na telefonu: sedam dana, izabran istaknut; dani
/// van plana se ne biraju.
class PlanWeekStrip extends StatelessWidget {
  const PlanWeekStrip({
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
    final days = weekOf(selected).days.toList();
    return TavliWeekStrip(
      selectedIndex: days.indexOf(selected),
      onSelected: (i) => onSelect(days[i]),
      days: [
        for (final d in days)
          TavliStripDay(
            weekday: weekdayShort(d),
            day: '${d.day}',
            enabled: plan.range.contains(d),
            semanticLabel: daySemantics(
              d,
              meals.where((m) => m.slot.date == d).length,
              today,
            ),
          ),
      ],
    );
  }
}

/// Nedelja na računaru: kolona za svaki dan, red za svaki obrok plana.
class PlanWeekGrid extends StatelessWidget {
  const PlanWeekGrid({
    super.key,
    required this.plan,
    required this.bySlot,
    required this.selected,
    required this.onOpen,
  });

  final MealPlan plan;
  final Map<MealSlot, PlannedMeal> bySlot;
  final CivilDate selected;
  final ValueChanged<PlannedMeal> onOpen;

  @override
  Widget build(BuildContext context) {
    final days = weekOf(selected).days.toList();
    return TavliWeekGrid(
      days: [
        for (final d in days)
          TavliWeekDay(
            weekday: weekdayShort(d),
            day: '${d.day}',
            semanticLabel: dayLabel(d),
            highlighted: d == selected,
          ),
      ],
      rows: [
        for (final type in MealType.values)
          if (plan.mealTypes.contains(type))
            [
              for (final d in days)
                plan.range.contains(d)
                    ? MealEntryCard(
                        slot: MealSlot(d, type),
                        meal: bySlot[MealSlot(d, type)],
                        onTap: onOpen,
                        compact: true,
                      )
                    : null,
            ],
      ],
    );
  }
}
