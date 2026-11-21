import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/meal_plan.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/shopping_demand.dart' show maxServings, scaleQuantity;
import 'meal_actions.dart';
import 'plan_format.dart';
import 'planning_providers.dart';

/// Odobren recept obroka i izmene: porcije, zamena, zaključavanje,
/// skuvano i uklanjanje. Prikazuje snimak iz plana, ne recept iz biblioteke.
///
/// Naslov (naziv jela) i povratak daje okvir ekrana.
class MealEntryDetail extends ConsumerWidget {
  const MealEntryDetail({
    super.key,
    required this.plan,
    required this.meal,
    this.onRemoved,
  });

  final MealPlan plan;
  final PlannedMeal meal;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final repo = ref.read(mealPlanRepositoryProvider);
    final snapshot = meal.snapshot;
    final protected = meal.isLocked || meal.isCooked;
    final muted = t.bodyMedium?.copyWith(color: c.onSurfaceVariant);
    final body = t.bodyLarge?.copyWith(color: c.onSurface);

    Future<void> remove() async {
      final ok = await showTavliConfirm(
        context,
        title: 'Ukloniti obrok iz plana?',
        message: 'Njegovi sastojci izlaze iz nabavke. Kupljeno ostaje.',
        confirmLabel: 'Ukloni',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      if (await runMealEdit(context, () => repo.removeMeal(meal.id))) {
        onRemoved?.call();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TavliSectionHeader(
              '${dayLabel(meal.slot.date)} · ${meal.slot.type.label}',
            ),
            if (protected)
              TavliNotice(
                tone: meal.isCooked
                    ? TavliNoticeTone.success
                    : TavliNoticeTone.info,
                title: [
                  if (meal.isLocked) 'Zaključano',
                  if (meal.isCooked) 'Skuvano',
                ].join(' · '),
                message: meal.isCooked
                    ? 'Skuvan obrok se ne menja.'
                    : 'Za zamenu ili uklanjanje prvo otključaj obrok.',
              ),
          ],
        ),
        TavliListGroup(
          children: [
            TavliListRow(
              title: 'Broj porcija',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TavliIconButton(
                    icon: Icons.remove,
                    semanticLabel: 'Manje porcija',
                    onPressed: meal.isCooked || meal.servings <= 1
                        ? null
                        : () => runMealEdit(
                            context,
                            () =>
                                repo.changeServings(meal.id, meal.servings - 1),
                          ),
                  ),
                  Text('${meal.servings}', style: t.titleMedium),
                  TavliIconButton(
                    glyph: TavliIcons.add,
                    semanticLabel: 'Više porcija',
                    onPressed: meal.isCooked || meal.servings >= maxServings
                        ? null
                        : () => runMealEdit(
                            context,
                            () =>
                                repo.changeServings(meal.id, meal.servings + 1),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Sporedna dugmad su iste visine; u redu kad staju, inače jedno
        // ispod drugog.
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            if (snapshot != null && !meal.isCooked)
              TavliButton.primary(
                label: 'Kuvaj',
                glyph: TavliIcons.cook,
                onPressed: () =>
                    context.push('/cook/meal/${plan.id}/${meal.id}'),
              ),
            TavliButton.secondary(
              label: 'Zameni jelo',
              glyph: TavliIcons.edit,
              onPressed: protected
                  ? null
                  : () => replaceMeal(context, ref, plan, meal),
            ),
            TavliButton.secondary(
              label: meal.isLocked ? 'Otključaj' : 'Zaključaj',
              icon: meal.isLocked
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
              onPressed: meal.isCooked
                  ? null
                  : () => runMealEdit(
                      context,
                      () => repo.setLocked(meal.id, locked: !meal.isLocked),
                    ),
            ),
            TavliButton.secondary(
              label: meal.isCooked ? 'Nije skuvano' : 'Označi kao skuvano',
              icon: meal.isCooked ? Icons.undo_rounded : null,
              glyph: meal.isCooked ? null : TavliIcons.check,
              onPressed: () => runMealEdit(context, () async {
                final cooking = ref.read(cookingRepositoryProvider);
                meal.isCooked
                    ? await cooking.undoCooked(meal.id)
                    : await cooking.markCooked(meal.id);
              }),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TavliButton.destructive(
            label: 'Ukloni iz plana',
            glyph: TavliIcons.delete,
            onPressed: protected ? null : remove,
          ),
        ),
        if (snapshot != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.small,
            children: [
              TavliSectionHeader(
                'Sastojci za ${servingsLabel(meal.servings)}'
                '${snapshot.prepMinutes == null ? '' : ' · ${snapshot.prepMinutes} min'}',
                style: TavliSectionHeaderStyle.bold,
              ),
              for (final i in snapshot.ingredients)
                Text(
                  '• ${ingredientLine(i.quantity == null ? i : Ingredient(
                          name: i.name,
                          quantity: scaleQuantity(i.quantity, baseServings: snapshot.baseServings, servings: meal.servings),
                          unit: i.unit,
                          category: i.category,
                          note: i.note,
                        ))}',
                  style: body,
                ),
            ],
          ),
          if (snapshot.steps.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.small,
              children: [
                const TavliSectionHeader(
                  'Priprema',
                  style: TavliSectionHeaderStyle.bold,
                ),
                for (final (n, step) in snapshot.steps.indexed)
                  Text('${n + 1}. $step', style: body),
              ],
            )
          else
            Text('Ovaj recept u planu nema korake pripreme.', style: muted),
        ],
      ],
    );
  }
}
