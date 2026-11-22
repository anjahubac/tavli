import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/empty_tabs.dart';
import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../app/tab_app_bar.dart';
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe_format.dart';
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
          AsyncValue(hasError: true) => _ScrollableCenter(
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
    if (day.today.isEmpty && notice == null) {
      return _ScrollableCenter(child: _HomeEmptyState(hasPlans: day.hasPlans));
    }

    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final header = TavliPageHeader(
      title: 'Danas',
      overline: dayLabel(day.date),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Kao na platnu: napomena i sutrašnji obroci desno na širokom ekranu.
        final side = constraints.maxWidth >= TavliWidth.listDetail;
        final today = day.today.isEmpty
            ? _HomeEmptyState(hasPlans: day.hasPlans)
            : _TodayMeals(day: day, columns: side ? 2 : 1);
        final noticeCard = notice == null
            ? null
            : _HomeNoticeCard(notice: notice, date: day.date);
        return SingleChildScrollView(
          padding: wide
              ? const EdgeInsets.fromLTRB(28, 24, 28, 24)
              : const EdgeInsets.fromLTRB(
                  TavliSpacing.large,
                  TavliSpacing.small,
                  TavliSpacing.large,
                  TavliSpacing.large,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: wide ? 16 : TavliSpacing.medium,
            children: [
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
                        width: math.min(
                          TavliWidth.detail,
                          constraints.maxWidth / 3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: TavliSpacing.medium,
                          children: [
                            ?noticeCard,
                            if (day.tomorrow.isNotEmpty)
                              _TomorrowCard(meals: day.tomorrow),
                          ],
                        ),
                      ),
                  ],
                )
              else ...[
                today,
                ?noticeCard,
                if (day.tomorrow.isNotEmpty) _TomorrowLine(meals: day.tomorrow),
              ],
            ],
          ),
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
  const _TodayMeals({required this.day, required this.columns});

  final HomeDay day;
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = day.next;
    final at = next == null ? day.today.length : day.today.indexOf(next);
    final before = day.today.sublist(0, at);
    final after = next == null ? <PlannedMeal>[] : day.today.sublist(at + 1);

    Widget grid(List<PlannedMeal> meals) => TavliCardGrid(
      itemCount: meals.length,
      columns: columns,
      spacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) => _MealCard(
        meal: meals[i],
        onTap: () => _openPlannedMeal(context, meals[i]),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (before.isNotEmpty) grid(before),
        if (next != null)
          _NextMealCard(
            meal: next,
            onCook: () => _openPlannedMeal(context, next),
            onCooked: () => unawaited(_markMealCooked(context, ref, next)),
          ),
        if (after.isNotEmpty) grid(after),
        if (day.allCooked) const _AllCooked(),
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

/// Obrok koji nije sledeći: skuvan (zasenčen, kvačica i „skuvano“ u
/// tekstu) ili kasnije u danu.
class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.onTap});

  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final cooked = meal.isCooked;
    return TavliCard(
      variant: cooked ? TavliCardVariant.cooked : TavliCardVariant.plain,
      onTap: onTap,
      // Desno mesta za kvačicu skuvanog obroka.
      padding: EdgeInsetsDirectional.fromSTEB(16, 14, cooked ? 34 : 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            cooked ? '${meal.slot.type.label} · skuvano' : meal.slot.type.label,
            style: t.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: muted,
            ),
          ),
          Text(
            _title(meal),
            style: t.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: cooked ? muted : null,
            ),
          ),
          if (!cooked)
            Text(
              _details(meal),
              style: t.bodySmall?.copyWith(fontSize: 13, color: muted),
            ),
        ],
      ),
    );
  }
}

/// Sledeći neskuvan obrok: istaknuta kartica sa „Kuvaj“ i „Skuvano“.
class _NextMealCard extends StatelessWidget {
  const _NextMealCard({
    required this.meal,
    required this.onCook,
    required this.onCooked,
  });

  final PlannedMeal meal;
  final VoidCallback onCook;
  final VoidCallback onCooked;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titleSize = _isWide(context) ? 24.0 : 20.0;
    final overline = 'Sledeće · ${meal.slot.type.label}';
    return TavliCard(
      variant: TavliCardVariant.highlighted,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline.toUpperCase(),
            semanticsLabel: overline,
            style: t.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.72,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              _title(meal),
              style: t.titleLarge?.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02 * titleSize,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(_details(meal), style: t.bodyMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: 14),
          // U redu kada staju (iste visine), inače jedno ispod drugog.
          OverflowBar(
            spacing: 10,
            overflowSpacing: 10,
            children: [
              TavliButton.primary(
                label: 'Kuvaj',
                glyph: TavliIcons.cook,
                onPressed: onCook,
              ),
              TavliButton.secondary(
                label: 'Skuvano',
                glyph: TavliIcons.check,
                onPressed: onCooked,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutWidth;

class _AllCooked extends StatelessWidget {
  const _AllCooked();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TavliSpacing.small),
      child: Text(
        'Svi današnji obroci su skuvani.',
        style: t.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Telefon: „Sutra“ i nazivi jela u jednom redu.
class _TomorrowLine extends StatelessWidget {
  const _TomorrowLine({required this.meals});

  final List<PlannedMeal> meals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TavliSectionHeader('Sutra'),
        Text(
          meals.map(_title).join(' · '),
          style: t.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
        ),
      ],
    );
  }
}

/// Širok ekran: kartica „Sutra“ desno, obrok po red.
class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard({required this.meals});

  final List<PlannedMeal> meals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TavliCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: TavliSectionHeader('Sutra'),
          ),
          for (final (i, meal) in meals.indexed) ...[
            if (i > 0) const TavliDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.slot.type.label,
                    style: t.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  Text(
                    _title(meal),
                    style: t.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Prazno stanje ili greška: u sredini, a pomera se kada ne staje.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

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
