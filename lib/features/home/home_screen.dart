import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/empty_tabs.dart';
import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../app/tab_app_bar.dart';
import '../../domain/church_calendar.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe_format.dart';
import '../fasting/fasting_questions.dart';
import '../planning/meal_actions.dart' show mealErrorText;
import '../planning/plan_format.dart';
import '../planning/planning_providers.dart';
import '../shopping/shopping_providers.dart';
import 'home_notice.dart';
import 'home_today.dart';

/// Početna (021 FR-008): današnji obroci po platnu. Skuvani su zasenčeni,
/// sledeći neskuvan je istaknut sa „Kuvaj“, a ispod su sutrašnji obroci.
/// „Skuvano“ označava sledeći obrok uz „Poništi“. „Na umu“ izdvaja jednu
/// napomenu za današnje i sutrašnje obroke.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(homeDayProvider);
    return Scaffold(
      appBar: const TabAppBar(),
      body: SafeArea(
        child: switch (day) {
          AsyncValue(:final value?, hasError: false) => _HomeContent(
            day: value,
          ),
          AsyncValue(hasError: true) => TavliPage.centered(
            child: TavliEmptyState(
              glyph: TavliIcons.info,
              title: 'Današnji obroci trenutno ne mogu da se prikažu.',
              action: TavliButton.primary(
                label: 'Pokušaj ponovo',
                onPressed: () {
                  ref
                    ..invalidate(mealPlansProvider)
                    ..invalidate(plannedMealsProvider);
                },
              ),
            ),
          ),
          _ => const TavliLoading(),
        },
      ),
    );
  }
}

/// Otvara obrok sa koracima pripreme na postojećoj adresi u Planu.
void _openPlannedMeal(BuildContext context, PlannedMeal meal) {
  unawaited(context.push('/plan/${meal.planId}/entries/${meal.id}'));
}

/// „Skuvano“ sa Početne: deljena radnja (isto kao u Planu), pa poruka sa
/// „Poništi“. Posle poruke poništavanje ostaje u detalju obroka.
Future<void> _markMealCooked(
  BuildContext context,
  WidgetRef ref,
  PlannedMeal meal,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final cooking = ref.read(cookingRepositoryProvider);
  try {
    await cooking.markCooked(meal.id);
  } on Exception catch (e) {
    showTavliMessageOn(messenger, mealErrorText(e));
    return;
  }
  showTavliMessageOn(
    messenger,
    'Skuvano: ${_title(meal)}',
    actionLabel: 'Poništi',
    onAction: () => unawaited(() async {
      try {
        await cooking.undoCooked(meal.id);
      } on Exception catch (e) {
        showTavliMessageOn(messenger, mealErrorText(e));
      }
    }()),
  );
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.day});

  final HomeDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(homeNoticeProvider);
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final fasting = FastingStatusCard(
      calendar: ChurchCalendar(day.date.toWire()),
    );
    final header = TavliPageHeader(
      title: 'Danas',
      overline: dayLabel(day.date),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Kao na platnu: napomena i sutrašnji obroci desno na širokom ekranu.
        final side = constraints.maxWidth >= TavliWidth.listDetail;
        final today = _TodayMeals(
          day: day,
          columns: side ? TavliColumns.meals : 1,
          wide: wide,
        );
        final noticeCard = notice == null
            ? null
            : _HomeNoticeCard(notice: notice, date: day.date);
        if (day.today.isEmpty) {
          // Prazan dan: zaglavlje ostaje gore, a crtež je na istoj visini
          // kao na ostalim tabovima (TavliEmptyArea).
          return TavliEmptyArea(
            padding: TavliPage.padding(wide: wide),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliPage.spacing(wide: wide),
              children: [
                if (side)
                  Row(
                    spacing: TavliSpacing.large,
                    children: [
                      Expanded(child: header),
                      SizedBox(
                        width: TavliWidth.side(constraints.maxWidth),
                        child: fasting,
                      ),
                    ],
                  )
                else ...[
                  header,
                  fasting,
                ],
                if (side && (noticeCard != null || day.tomorrow.isNotEmpty))
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: TavliWidth.side(constraints.maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: TavliSpacing.cardsWide,
                        children: [
                          ?noticeCard,
                          if (day.tomorrow.isNotEmpty)
                            _Tomorrow(meals: day.tomorrow, card: true),
                        ],
                      ),
                    ),
                  )
                else if (!side) ...[
                  ?noticeCard,
                  if (day.tomorrow.isNotEmpty) _Tomorrow(meals: day.tomorrow),
                ],
              ],
            ),
            child: _HomeEmptyState(hasPlans: day.hasPlans),
          );
        }
        return TavliPage(
          wide: wide,
          children: [
            if (side)
              Row(
                spacing: TavliSpacing.large,
                children: [
                  Expanded(child: header),
                  SizedBox(
                    width: TavliWidth.side(constraints.maxWidth),
                    child: fasting,
                  ),
                ],
              )
            else
              header,
            if (side)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TavliSpacing.large,
                children: [
                  Expanded(child: today),
                  if (noticeCard != null || day.tomorrow.isNotEmpty)
                    SizedBox(
                      // Najviše trećina sadržaja, kao detalj pored liste.
                      width: TavliWidth.side(constraints.maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: TavliSpacing.cardsWide,
                        children: [
                          ?noticeCard,
                          if (day.tomorrow.isNotEmpty)
                            _Tomorrow(meals: day.tomorrow, card: true),
                        ],
                      ),
                    ),
                ],
              )
            else ...[
              today,
              fasting,
              ?noticeCard,
              if (day.tomorrow.isNotEmpty) _Tomorrow(meals: day.tomorrow),
            ],
          ],
        );
      },
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.hasPlans});

  final bool hasPlans;

  @override
  Widget build(BuildContext context) => TavliEmptyState(
    art: const EmptyTable(),
    title: hasPlans ? 'Za danas nema obroka u planu' : 'Još nema plana obroka',
    message: hasPlans
        ? 'Pogledaj plan ili napravi nov za ove dane.'
        : 'Napravi plan i ovde ćeš videti šta se danas kuva.',
    action: TavliButton.primary(
      label: hasPlans ? 'Otvori plan' : 'Napravi plan',
      glyph: TavliIcons.plan,
      onPressed: () => context.go(hasPlans ? '/plan' : '/plan/new'),
    ),
  );
}

class _HomeNoticeCard extends ConsumerWidget {
  const _HomeNoticeCard({required this.notice, required this.date});

  final HomeNotice notice;
  final CivilDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (notice) {
    MissingShoppingNotice(:final meal) => TavliNotice(
      title: 'Na umu',
      tone: TavliNoticeTone.warning,
      message: meal.slot.date == date
          ? 'Za današnje jelo „${_title(meal)}“ nedostaju namirnice.'
          : 'Za sutrašnje jelo „${_title(meal)}“ nedostaju namirnice.',
      linkLabel: 'Nabavka',
      onLink: () {
        final plans = ref.read(mealPlansProvider).value ?? const <MealPlan>[];
        final plan = plans.where((plan) => plan.id == meal.planId).firstOrNull;
        final week = plan == null
            ? null
            : periodFor(plan.range, meal.slot.date);
        final shopping = ref.read(shoppingViewProvider.notifier);
        ref.read(planViewProvider.notifier).selectPlan(meal.planId);
        shopping.setMode(ShoppingMode.plan);
        if (week != null) shopping.selectWeek(week.range.start);
        context.go('/shopping');
      },
    ),
    PlanEndingNotice() => const TavliNotice(
      title: 'Na umu',
      message: 'Plan se završava za dva dana.',
    ),
  };
}

/// Današnji obroci redom: pre sledećeg (skuvani), sledeći istaknut, pa
/// ostali. Na širokom ekranu obroci pre i posle sledećeg idu u dve kolone.
class _TodayMeals extends ConsumerWidget {
  const _TodayMeals({
    required this.day,
    required this.columns,
    required this.wide,
  });

  final HomeDay day;
  final int columns;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = day.next;
    final at = next == null ? day.today.length : day.today.indexOf(next);
    final before = day.today.sublist(0, at);
    final after = next == null ? <PlannedMeal>[] : day.today.sublist(at + 1);

    // Kao na platnu: 10 između kartica na telefonu, 12 na računaru.
    final gap = wide ? TavliSpacing.cardsWide : TavliSpacing.cards;
    Widget grid(List<PlannedMeal> meals) => TavliCardGrid(
      itemCount: meals.length,
      columns: columns,
      spacing: gap,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final meal = meals[i];
        return TavliMealCard(
          label: meal.slot.type.label,
          title: _title(meal),
          detail: meal.isCooked ? null : _details(meal),
          cooked: meal.isCooked,
          onTap: () => _openPlannedMeal(context, meal),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (before.isNotEmpty) grid(before),
        if (next != null)
          TavliNextMealCard(
            overline: 'Sledeće · ${next.slot.type.label}',
            title: _title(next),
            detail: _details(next),
            wide: wide,
            actions: [
              TavliButton.primary(
                label: 'Kuvaj',
                glyph: TavliIcons.cook,
                onPressed: () => _openPlannedMeal(context, next),
              ),
              TavliButton.secondary(
                label: 'Skuvano',
                glyph: TavliIcons.check,
                onPressed: () => unawaited(_markMealCooked(context, ref, next)),
              ),
            ],
          ),
        if (after.isNotEmpty) grid(after),
        if (day.allCooked)
          const TavliStatusText('Svi današnji obroci su skuvani.'),
      ],
    );
  }
}

String _title(PlannedMeal meal) =>
    meal.snapshot?.title ?? 'Recept nije dostupan';

String _details(PlannedMeal meal) => [
  if (meal.snapshot?.prepMinutes case final m?) '$m min',
  servingsLabel(meal.servings),
].join(' · ');

/// „Sutra“: na telefonu nazivi jela u jednom redu, na širokom ekranu
/// kartica desno sa obrokom po redu.
class _Tomorrow extends StatelessWidget {
  const _Tomorrow({required this.meals, this.card = false});

  final List<PlannedMeal> meals;
  final bool card;

  @override
  Widget build(BuildContext context) => TavliUpcomingMeals(
    title: 'Sutra',
    card: card,
    meals: [
      for (final meal in meals)
        TavliUpcomingMeal(label: meal.slot.type.label, title: _title(meal)),
    ],
  );
}
