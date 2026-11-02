import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/placeholder_screen.dart';
import '../../app/tab_app_bar.dart';
import '../../domain/meal_plan.dart';
import '../../domain/recipe_format.dart';
import '../recipes/recipe_providers.dart';
import '../recipes/recipe_view.dart';
import 'plan_format.dart';
import 'planning_providers.dart';

/// Tab Plan. Bez plana je glavna akcija "Napravi plan"; sa planom prikazuje
/// izabrani plan po danima (kalendar nedelje i meseca dolazi kasnije).
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(mealPlansProvider);
    return plans.when(
      loading: () => const Scaffold(
        appBar: TabAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const EmptyStateScreen(
        art: Icon(Icons.error_outline, size: 56),
        title: 'Plan trenutno ne može da se prikaže',
      ),
      data: (list) {
        final plan = selectDefaultPlan(list, ref.watch(clockProvider)());
        if (plan == null) {
          return EmptyStateScreen(
            art: Icon(
              Icons.calendar_month_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: 'Još nemaš plan',
            body:
                'Izaberi nedelju ili mesec i obroke; predlog pregledaš '
                'pre čuvanja.',
            action: FilledButton.icon(
              onPressed: () => context.go('/plan/new'),
              icon: const Icon(Icons.add),
              label: const Text('Napravi plan'),
            ),
          );
        }
        return _SavedPlan(plan: plan);
      },
    );
  }
}

class _SavedPlan extends ConsumerWidget {
  const _SavedPlan({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meals = ref.watch(plannedMealsProvider(plan.id)).value ?? const [];
    final bySlot = {for (final m in meals) m.slot: m};
    return Scaffold(
      appBar: const TabAppBar(),
      body: ReadableScroll(
        children: [
          Text(rangeLabel(plan.range), style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${mealsCount(meals.length)} · '
            '${servingsLabel(plan.defaultServings)} po obroku',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/shopping'),
            icon: const Icon(Icons.shopping_basket_outlined),
            label: const Text('Otvori nabavku'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/plan/new'),
            icon: const Icon(Icons.add),
            label: const Text('Napravi novi plan'),
          ),
          for (final day in plan.range.days) ...[
            const SizedBox(height: 16),
            Text(dayLabel(day), style: theme.textTheme.titleMedium),
            for (final slot in plan.slots.where((s) => s.date == day))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(slot.type.label, style: theme.textTheme.labelLarge),
                subtitle: Text(
                  bySlot[slot]?.snapshot?.title ?? 'Nije planirano',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
