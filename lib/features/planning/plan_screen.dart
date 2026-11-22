import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/empty_tabs.dart';
import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../app/tab_app_bar.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../recipes/recipe_providers.dart';
import '../settings/settings_page.dart';
import 'meal_entry_card.dart';
import 'meal_entry_detail.dart';
import 'plan_calendar.dart';
import 'plan_format.dart';
import 'plan_generation.dart';
import 'planning_providers.dart';

/// Širok ekran (bočna navigacija): zaglavlje „Plan“ sa izborom perioda
/// umesto gornje trake, a akcije dole desno umesto zakucane trake.
bool isWidePlan(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutWidth;

/// Tab Plan. Bez plana je glavna akcija "Napravi plan"; sa planom prikazuje
/// izabranu nedelju ili mesec, a glavne akcije su "Ponovo predloži" i
/// "Otvori nabavku".
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(mealPlansProvider);
    return Scaffold(
      appBar: const TabAppBar(),
      body: SafeArea(
        child: plans.when(
          loading: () => const TavliLoading(),
          error: (_, _) => _Scrollable(
            child: TavliEmptyState(
              glyph: TavliIcons.info,
              title: 'Plan trenutno ne može da se prikaže',
              action: TavliButton.primary(
                label: 'Pokušaj ponovo',
                onPressed: () => ref.invalidate(mealPlansProvider),
              ),
            ),
          ),
          data: (list) {
            final view = ref.watch(planViewProvider);
            final plan = selectedPlan(list, view, ref.watch(clockProvider)());
            if (plan == null) {
              return _Scrollable(
                child: TavliEmptyState(
                  art: const EmptyWeek(),
                  title: 'Još nemaš plan',
                  message:
                      'Izaberi nedelju ili mesec i obroke; predlog pregledaš '
                      'pre čuvanja.',
                  action: TavliButton.primary(
                    label: 'Napravi plan',
                    glyph: TavliIcons.add,
                    onPressed: () => context.go('/plan/new'),
                  ),
                ),
              );
            }
            return _PlanView(plans: list, plan: plan);
          },
        ),
      ),
    );
  }
}

/// Prazno stanje koje se pomera kada ne staje, a inače stoji u sredini.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}

class _PlanView extends ConsumerWidget {
  const _PlanView({required this.plans, required this.plan});

  final List<MealPlan> plans;
  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(planViewProvider);
    final controller = ref.read(planViewProvider.notifier);
    final today = CivilDate.today(ref.watch(clockProvider));
    final selected = selectedDate(plan, view, today);
    final meals = ref.watch(plannedMealsProvider(plan.id)).value ?? const [];
    final bySlot = {for (final m in meals) m.slot: m};
    final month = view.mode == PlanViewMode.month;
    final wide = isWidePlan(context);

    void open(PlannedMeal meal) =>
        unawaited(context.push('/plan/${plan.id}/entries/${meal.id}'));

    Future<void> regenerate() async {
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final started = await ref
          .read(planGenerationProvider.notifier)
          .regenerate(plan, meals);
      if (started) {
        router.go('/plan/new/preview');
      } else {
        showTavliMessageOn(
          messenger,
          'Nema obroka za novi predlog: ostali su zaključani, skuvani '
          'ili prošli.',
        );
      }
    }

    // Strelice idu kroz nedelje ili mesece plana; izabran dan ostaje u
    // planu.
    CivilDate clamp(CivilDate d) => d.isBefore(plan.range.start)
        ? plan.range.start
        : d.isAfter(plan.range.end)
        ? plan.range.end
        : d;
    final week = weekOf(selected);
    final monthRange = monthOf(selected);
    final period = month
        ? TavliPeriodSwitcher(
            compact: wide,
            label: monthLabel(selected),
            previousLabel: 'Prethodni mesec',
            nextLabel: 'Sledeći mesec',
            onPrevious: plan.range.start.isBefore(monthRange.start)
                ? () => controller.selectDate(
                    clamp(monthOf(monthRange.start.addDays(-1)).start),
                  )
                : null,
            onNext: plan.range.end.isAfter(monthRange.end)
                ? () => controller.selectDate(clamp(monthRange.end.addDays(1)))
                : null,
          )
        : TavliPeriodSwitcher(
            compact: wide,
            label: weekLabel(week),
            previousLabel: 'Prethodna nedelja',
            nextLabel: 'Sledeća nedelja',
            onPrevious: plan.range.start.isBefore(week.start)
                ? () => controller.selectDate(
                    clamp(selected.addDays(-DateTime.daysPerWeek)),
                  )
                : null,
            onNext: plan.range.end.isAfter(week.end)
                ? () => controller.selectDate(
                    clamp(selected.addDays(DateTime.daysPerWeek)),
                  )
                : null,
          );
    final todayButton = TavliButton.text(
      label: 'Danas',
      glyph: TavliIcons.today,
      onPressed: plan.range.contains(today)
          ? () => controller.selectDate(today)
          : null,
    );
    final modeChoice = TavliChoice<PlanViewMode>.segmented(
      options: const [
        TavliOption(PlanViewMode.week, 'Nedelja'),
        TavliOption(PlanViewMode.month, 'Mesec'),
      ],
      selected: view.mode,
      onChanged: controller.setMode,
    );
    final picker = plans.length > 1
        ? _PlanPicker(plans: plans, plan: plan)
        : null;
    const newPlanLabel = 'Napravi novi plan';
    final regenerateButton = TavliButton.secondary(
      label: 'Ponovo predloži',
      onPressed: regenerate,
    );

    if (!wide) {
      final dayMeals = [
        for (final slot in plan.slots.where((s) => s.date == selected))
          (slot, bySlot[slot]),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              key: PageStorageKey(('plan', plan.id)),
              padding: const EdgeInsets.fromLTRB(
                TavliSpacing.large,
                TavliSpacing.small,
                TavliSpacing.large,
                TavliSpacing.large,
              ),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: TavliSpacing.small,
                  children: [modeChoice, todayButton],
                ),
                const SizedBox(height: TavliSpacing.small),
                period,
                const SizedBox(height: TavliSpacing.small),
                if (month) ...[
                  PlanMonthCalendar(
                    plan: plan,
                    meals: meals,
                    selected: selected,
                    today: today,
                    onSelect: controller.selectDate,
                  ),
                  const SizedBox(height: TavliSpacing.small),
                  const TavliCalendarLegend(),
                  const SizedBox(height: TavliSpacing.medium),
                  if (dayMeals.isNotEmpty)
                    TavliMealList(
                      children: [
                        for (final (slot, meal) in dayMeals)
                          mealRow(slot, meal, onTap: open),
                      ],
                    ),
                ] else ...[
                  PlanWeekStrip(
                    plan: plan,
                    meals: meals,
                    selected: selected,
                    today: today,
                    onSelect: controller.selectDate,
                  ),
                  const SizedBox(height: TavliSpacing.small),
                  TavliSectionHeader(
                    dayLabel(selected),
                    style: TavliSectionHeaderStyle.title,
                  ),
                  for (final (i, (slot, meal)) in dayMeals.indexed) ...[
                    if (i > 0) const SizedBox(height: TavliSpacing.small),
                    MealEntryCard(slot: slot, meal: meal, onTap: open),
                  ],
                ],
                const SizedBox(height: TavliSpacing.large),
                if (picker != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: picker,
                  ),
                  const SizedBox(height: TavliSpacing.small),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TavliButton.text(
                    label: newPlanLabel,
                    glyph: TavliIcons.add,
                    onPressed: () => context.go('/plan/new'),
                  ),
                ),
              ],
            ),
          ),
          TavliActionBar(
            actions: [
              regenerateButton,
              TavliButton.primary(
                label: 'Otvori nabavku',
                onPressed: () => context.go('/shopping'),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(TavliSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TavliSpacing.medium,
        children: [
          TavliPageHeader(
            title: 'Plan',
            actions: [period, todayButton, modeChoice],
          ),
          if (picker != null)
            Align(alignment: AlignmentDirectional.centerStart, child: picker),
          Expanded(
            child: month
                ? PlanMonthCalendar(
                    plan: plan,
                    meals: meals,
                    selected: selected,
                    today: today,
                    detailed: true,
                    // Dan iz meseca otvara njegovu nedelju.
                    onSelect: (d) {
                      controller
                        ..selectDate(d)
                        ..setMode(PlanViewMode.week);
                    },
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= TavliWidth.weekGrid
                        ? PlanWeekGrid(
                            plan: plan,
                            bySlot: bySlot,
                            selected: selected,
                            onOpen: open,
                          )
                        : ListView(
                            key: PageStorageKey(('plan', plan.id)),
                            children: [
                              PlanWeekStrip(
                                plan: plan,
                                meals: meals,
                                selected: selected,
                                today: today,
                                onSelect: controller.selectDate,
                              ),
                              const SizedBox(height: TavliSpacing.small),
                              TavliSectionHeader(
                                dayLabel(selected),
                                style: TavliSectionHeaderStyle.title,
                              ),
                              for (final slot in plan.slots.where(
                                (s) => s.date == selected,
                              )) ...[
                                MealEntryCard(
                                  slot: slot,
                                  meal: bySlot[slot],
                                  onTap: open,
                                ),
                                const SizedBox(height: TavliSpacing.small),
                              ],
                            ],
                          ),
                  ),
          ),
          // Akcije dole desno, sve iste visine; kad ne staju u red, jedna
          // ispod druge.
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: TavliSpacing.small,
            overflowSpacing: TavliSpacing.small,
            children: [
              TavliButton.secondary(
                label: newPlanLabel,
                glyph: TavliIcons.add,
                onPressed: () => context.go('/plan/new'),
              ),
              regenerateButton,
              TavliButton.primary(
                label: 'Otvori nabavku',
                glyph: TavliIcons.shopping,
                onPressed: () => context.go('/shopping'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Izbor plana kada ih ima više: dugme sa opsegom izabranog plana otvara
/// meni sa planovima (isto kao u Nabavci).
class _PlanPicker extends ConsumerWidget {
  const _PlanPicker({required this.plans, required this.plan});

  final List<MealPlan> plans;
  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: 'Izaberi plan',
    child: TavliButton.secondary(
      label: rangeLabel(plan.range),
      glyph: TavliIcons.plan,
      onPressed: () {
        final box = context.findRenderObject()! as RenderBox;
        unawaited(
          showTavliActionMenu(
            context,
            title: 'Izaberi plan',
            position: box.localToGlobal(box.size.bottomLeft(Offset.zero)),
            actions: [
              for (final p in plans)
                TavliMenuAction(
                  rangeLabel(p.range),
                  onSelected: () =>
                      ref.read(planViewProvider.notifier).selectPlan(p.id),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Obrok na svojoj adresi (`/plan/:planId/entries/:entryId`): telefon sa
/// trakom za povratak, računar sa povratkom „Plan“ iznad naslova.
class MealEntryScreen extends ConsumerWidget {
  const MealEntryScreen({
    super.key,
    required this.planId,
    required this.entryId,
  });

  final String planId;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(mealPlanProvider(planId)).value;
    final meals = ref.watch(plannedMealsProvider(planId));
    PlannedMeal? meal;
    for (final m in meals.value ?? const <PlannedMeal>[]) {
      if (m.id == entryId) meal = m;
    }
    return SettingsPage(
      title: meal?.snapshot?.title ?? 'Obrok',
      backLabel: 'Plan',
      fallbackLocation: '/plan',
      children: [
        if (plan == null || meal == null)
          meals.isLoading
              ? const TavliLoading()
              : const TavliEmptyState(
                  glyph: TavliIcons.info,
                  title: 'Obrok nije pronađen.',
                )
        else
          MealEntryDetail(
            plan: plan,
            meal: meal,
            onRemoved: () => context.go('/plan'),
          ),
      ],
    );
  }
}
