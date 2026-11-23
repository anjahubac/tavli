import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe_format.dart';
import '../../domain/shopping_demand.dart' show maxServings, minServings;
import '../recipes/recipe_providers.dart';
import 'plan_format.dart';
import 'plan_generation.dart';
import 'plan_preview_screen.dart';
import 'plan_step_page.dart';

/// Prvi korak: period, obroci i porcije na jednom ekranu; ostava i želje
/// su dodatne opcije koje nisu obavezne.
class PlanSetupScreen extends ConsumerStatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  ConsumerState<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends ConsumerState<PlanSetupScreen> {
  late final TextEditingController _wishes;

  @override
  void initState() {
    super.initState();
    _wishes = TextEditingController(
      text: ref.read(planGenerationProvider).setup.wishes,
    );
  }

  @override
  void dispose() {
    _wishes.dispose();
    super.dispose();
  }

  PlanGenerationController get _controller =>
      ref.read(planGenerationProvider.notifier);

  void _update(PlanSetup setup) => _controller.updateSetup(setup);

  void _start() {
    final state = ref.read(planGenerationProvider);
    // Otvoren nacrt istih izbora se samo ponovo prikazuje.
    // Napredak i greške pregled prati preko stanja.
    if (state.draft == null) unawaited(_controller.generate());
    context.go('/plan/new/preview');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planGenerationProvider);
    final setup = state.setup;
    final today = CivilDate.today(ref.watch(clockProvider));
    final range = setup.range(today);
    final theme = Theme.of(context);
    final slots = range == null ? 0 : range.dayCount * setup.mealTypes.length;
    final canStart = range != null && setup.mealTypes.isNotEmpty;

    final week = setup.period == PlanPeriod.week;
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
    final summary = canStart
        ? '${mealsCount(slots)} · ${servingsLabel(setup.servings)} po obroku'
        : null;
    final startButton = TavliButton.primary(
      label: state.draft == null ? 'Predloži plan' : 'Nazad na predlog',
      glyph: TavliIcons.sparkle,
      onPressed: canStart ? _start : null,
    );
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return PopScope(
      canPop: state.draft == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (await confirmDiscardPlan(context)) {
          _controller.discard();
          router.go('/plan');
        }
      },
      child: PlanStepPage(
        title: 'Novi plan',
        onBack: () => unawaited(_back()),
        bottom: TavliActionBar(actions: [startButton], note: summary),
        children: [
          _Section(
            title: 'Period',
            children: [
              TavliChoice<PlanPeriod>.segmented(
                options: const [
                  TavliOption(PlanPeriod.week, 'Nedelja'),
                  TavliOption(PlanPeriod.month, 'Mesec'),
                ],
                selected: setup.period,
                onChanged: (p) =>
                    _update(setup.copyWith(period: p, anchor: today)),
              ),
              TavliPeriodSwitcher(
                label: range == null ? 'Period je prošao' : rangeLabel(range),
                previousLabel: week ? 'Prethodna nedelja' : 'Prethodni mesec',
                nextLabel: week ? 'Sledeća nedelja' : 'Sledeći mesec',
                onPrevious: setup.shifted(-1).range(today) == null
                    ? null
                    : () => _update(setup.shifted(-1)),
                onNext: () => _update(setup.shifted(1)),
              ),
            ],
          ),
          _Section(
            title: 'Obroci',
            children: [
              TavliMultiChoice<MealType>(
                options: [
                  for (final t in MealType.values) TavliOption(t, t.label),
                ],
                selected: setup.mealTypes,
                onChanged: (types) => _update(setup.copyWith(mealTypes: types)),
              ),
              if (setup.mealTypes.isEmpty)
                Text(
                  'Izaberi bar jedan obrok.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          TavliCard(
            padding: const EdgeInsetsDirectional.only(
              start: TavliSpacing.medium,
              end: TavliSpacing.small,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Broj porcija',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TavliIconButton(
                  glyph: TavliIcons.remove,
                  semanticLabel: 'Manje porcija',
                  onPressed: setup.servings > minServings
                      ? () => _update(
                          setup.copyWith(servings: setup.servings - 1),
                        )
                      : null,
                ),
                Text('${setup.servings}', style: theme.textTheme.titleMedium),
                TavliIconButton(
                  glyph: TavliIcons.add,
                  semanticLabel: 'Više porcija',
                  onPressed: setup.servings < maxServings
                      ? () => _update(
                          setup.copyWith(servings: setup.servings + 1),
                        )
                      : null,
                ),
              ],
            ),
          ),
          TavliCard(
            padding: EdgeInsets.zero,
            child: TavliExpandable(
              title: 'Više opcija',
              subtitle: 'Ostava i posebni zahtevi, nije obavezno',
              initiallyExpanded: setup.wishes.isNotEmpty || !setup.usePantry,
              children: [
                TavliSwitchRow(
                  title: 'Koristi ostavu',
                  subtitle: 'Samo potvrđene namirnice',
                  value: setup.usePantry,
                  onChanged: (v) => _update(setup.copyWith(usePantry: v)),
                ),
                TavliTextField(
                  controller: _wishes,
                  label: 'Posebni zahtevi',
                  hint: 'npr. bez svinjetine, više povrća, posno petkom',
                  maxLines: TavliTextField.noteLines,
                  onChanged: (v) => _update(setup.copyWith(wishes: v)),
                ),
              ],
            ),
          ),
          if (wide)
            // Računar: sažetak levo, „Predloži plan“ desno (platno).
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: TavliSpacing.large,
              children: [
                if (summary != null)
                  Flexible(child: Text(summary, style: muted)),
                startButton,
              ],
            ),
        ],
      ),
    );
  }

  /// Povratak sa trake: isto kao sistemski povratak (pita pre odbacivanja
  /// otvorenog predloga).
  Future<void> _back() async {
    final router = GoRouter.of(context);
    if (!await Navigator.maybePop(context)) router.go('/plan');
  }
}

/// Naslov dela forme i izbori ispod njega.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.small,
    children: [TavliSectionHeader(title), ...children],
  );
}
