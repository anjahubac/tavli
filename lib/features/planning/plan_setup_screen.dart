import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/meal_plan.dart';
import '../../domain/plan_calendar.dart';
import '../../domain/recipe_format.dart';
import '../recipes/recipe_providers.dart';
import '../recipes/recipe_view.dart';
import 'plan_format.dart';
import 'plan_generation.dart';
import 'plan_preview_screen.dart';

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
      child: Scaffold(
        appBar: AppBar(title: const Text('Novi plan')),
        body: ReadableScroll(
          children: [
            Text('Period', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<PlanPeriod>(
              segments: const [
                ButtonSegment(value: PlanPeriod.week, label: Text('Nedelja')),
                ButtonSegment(value: PlanPeriod.month, label: Text('Mesec')),
              ],
              selected: {setup.period},
              onSelectionChanged: (s) =>
                  _update(setup.copyWith(period: s.single, anchor: today)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: setup.period == PlanPeriod.week
                      ? 'Prethodna nedelja'
                      : 'Prethodni mesec',
                  onPressed: setup.shifted(-1).range(today) == null
                      ? null
                      : () => _update(setup.shifted(-1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    range == null ? 'Period je prošao' : rangeLabel(range),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  tooltip: setup.period == PlanPeriod.week
                      ? 'Sledeća nedelja'
                      : 'Sledeći mesec',
                  onPressed: () => _update(setup.shifted(1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Obroci', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in MealType.values)
                  FilterChip(
                    label: Text(t.label),
                    selected: setup.mealTypes.contains(t),
                    onSelected: (on) => _update(
                      setup.copyWith(
                        mealTypes: on
                            ? {...setup.mealTypes, t}
                            : ({...setup.mealTypes}..remove(t)),
                      ),
                    ),
                  ),
              ],
            ),
            if (setup.mealTypes.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Izaberi bar jedan obrok.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Broj porcija',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Manje porcija',
                  onPressed: setup.servings > 1
                      ? () => _update(
                          setup.copyWith(servings: setup.servings - 1),
                        )
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('${setup.servings}', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: 'Više porcija',
                  onPressed: setup.servings < 20
                      ? () => _update(
                          setup.copyWith(servings: setup.servings + 1),
                        )
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Više opcija'),
              subtitle: const Text('Ostava i posebni zahtevi, nije obavezno'),
              initiallyExpanded: setup.wishes.isNotEmpty || !setup.usePantry,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Koristi ostavu'),
                  subtitle: const Text('Samo potvrđene namirnice'),
                  value: setup.usePantry,
                  onChanged: (v) => _update(setup.copyWith(usePantry: v)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _wishes,
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (v) => _update(setup.copyWith(wishes: v)),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Posebni zahtevi',
                    hintText: 'npr. bez svinjetine, više povrća, posno petkom',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canStart ? _start : null,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                state.draft == null ? 'Predloži plan' : 'Nazad na predlog',
              ),
            ),
            if (canStart) ...[
              const SizedBox(height: 8),
              Text(
                '${mealsCount(slots)} · ${servingsLabel(setup.servings)} po obroku',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
