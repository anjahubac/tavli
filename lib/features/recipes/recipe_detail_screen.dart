import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/shopping_source.dart';
import 'add_to_plan_sheet.dart';
import 'ingredient_review_sheet.dart';
import 'keep_screen_on.dart';
import 'recipe_labels_sheet.dart';
import 'recipe_providers.dart';
import 'recipe_rating_section.dart';
import 'recipe_view.dart';
import 'versions_sheet.dart';

/// Detalji recepta, kao ceo ekran.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recipeProvider(id))
        .when(
          loading: () => Scaffold(appBar: AppBar(), body: const TavliLoading()),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: const TavliEmptyState(
              glyph: TavliIcons.info,
              title: 'Recept nije učitan.',
            ),
          ),
          data: (recipe) => recipe == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const TavliEmptyState(
                    glyph: TavliIcons.recipes,
                    title: 'Recept više ne postoji.',
                  ),
                )
              : _Detail(recipe: recipe),
        );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.recipe});

  final Recipe recipe;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(recipeRepositoryProvider);
    final confirmed = await showTavliConfirm(
      context,
      title: 'Obrisati „${recipe.title}“?',
      message: 'Brišu se i prethodne verzije i slika.',
      confirmLabel: 'Obriši',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    // Poruka ide preko roditelja: ovaj ekran nestaje čim se recept obriše.
    final messenger = ScaffoldMessenger.of(context);
    context.go('/recipes');
    await repo.delete(recipe.id);
    showTavliMessageOn(messenger, 'Recept je obrisan.');
  }

  Future<void> _editLabels(BuildContext context, WidgetRef ref) async {
    final next = await showRecipeLabelsSheet(context, recipe.labels);
    if (next == null) return;
    await ref.read(recipeRepositoryProvider).setLabels(recipe.id, next);
    if (!context.mounted) return;
    showTavliMessageOn(ScaffoldMessenger.of(context), 'Oznake su sačuvane.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVersions =
        ref.watch(recipeVersionsProvider(recipe.id)).value?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        actions: [
          const KeepScreenOnButton(),
          TavliIconButton(
            semanticLabel: 'Izmeni',
            glyph: TavliIcons.edit,
            onPressed: () => context.go('/recipes/${recipe.id}/edit'),
          ),
          TavliMenuButton(
            actions: [
              TavliMenuAction(
                'Izmeni sa AI',
                onSelected: () => context.go('/recipes/${recipe.id}/chat'),
              ),
              TavliMenuAction(
                'Poništi poslednju izmenu',
                enabled: hasVersions,
                onSelected: () => undoLastChange(context, ref, recipe.id),
              ),
              TavliMenuAction(
                'Prethodne verzije',
                onSelected: () => showVersionsSheet(context, recipe.id),
              ),
              TavliMenuAction(
                'Obriši recept',
                isDestructive: true,
                onSelected: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
      body: KeepScreenOnScope(
        child: ReadableScroll(
          maxWidth: TavliWidth.page,
          children: [
            Semantics(
              header: true,
              child: Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: TavliSpacing.medium),
            _RecipeActions(
              cook: TavliButton.primary(
                label: 'Kuvaj',
                glyph: TavliIcons.cook,
                onPressed: () => context.push('/cook/recipe/${recipe.id}'),
              ),
              addToPlan: ({required withIcon}) => TavliButton.secondary(
                label: 'Dodaj u plan',
                glyph: withIcon ? TavliIcons.plan : null,
                onPressed: () => addRecipeToPlan(context, ref, recipe),
              ),
              check: TavliButton.secondary(
                label: 'Proveri sastojke',
                icon: Icons.checklist,
                onPressed: () => showIngredientReview(
                  context,
                  snapshot: RecipeSnapshot.fromRecipe(recipe),
                  originKey: 'recipe:${recipe.id}',
                  recipeId: recipe.id,
                ),
              ),
            ),
            const SizedBox(height: TavliSpacing.medium),
            RecipeRatingSection(recipeId: recipe.id),
            const SizedBox(height: TavliSpacing.large),
            RecipeView(
              recipe,
              onEditLabels: () => _editLabels(context, ref),
              ratingSummary: ref
                  .watch(recipeRatingSummaryProvider(recipe.id))
                  .value,
            ),
          ],
        ),
      ),
    );
  }
}

/// „Kuvaj“, „Dodaj u plan“ i „Proveri sastojke“, iste visine. Sva tri u
/// jednom redu kad im tekst staje u jedan red; inače prva dva u redu, a
/// „Proveri sastojke“ ispod celom širinom; kad ni to ne staje (uzak ekran,
/// veliki tekst), svako dugme je u svom redu. Tako tekst nijednog dugmeta
/// ne prelazi u drugi red i sva dugmad ostaju iste visine.
class _RecipeActions extends StatelessWidget {
  const _RecipeActions({
    required this.cook,
    required this.addToPlan,
    required this.check,
  });

  final TavliButton cook;

  /// Uži red na telefonu ga dobija bez ikonice, da tekst stane pored „Kuvaj“.
  final TavliButton Function({required bool withIcon}) addToPlan;
  final TavliButton check;

  /// Najveća širina reda; šire se dugmad ne razvlače.
  static const _maxWidth = 620.0;

  /// Razmak između dugmadi u redu ([TavliButtonRow]).
  static const _gap = 10.0;

  /// Unutrašnji razmak dugmeta levo i desno, sa ivicom.
  static const _padding = 42.0;

  /// Ikonica sa razmakom do teksta.
  static const _icon = 26.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
    final scaler = MediaQuery.textScalerOf(context);
    double need(String label, {required bool icon}) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width + _padding + (icon ? scaler.scale(_icon) : 0);
    }

    const gap = SizedBox(height: TavliSpacing.small);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final third = (w - 2 * _gap) / 3;
            final half = (w - _gap) / 2;
            if ([
              need('Kuvaj', icon: true),
              need('Dodaj u plan', icon: true),
              need('Proveri sastojke', icon: true),
            ].every((n) => n <= third)) {
              return TavliButtonRow(
                expand: true,
                children: [cook, addToPlan(withIcon: true), check],
              );
            }
            if (need('Kuvaj', icon: true) <= half &&
                need('Dodaj u plan', icon: false) <= half &&
                need('Proveri sastojke', icon: true) <= w) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TavliButtonRow(
                    expand: true,
                    children: [cook, addToPlan(withIcon: false)],
                  ),
                  gap,
                  TavliButtonRow(expand: true, children: [check]),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, b) in [
                  cook,
                  addToPlan(withIcon: true),
                  check,
                ].indexed) ...[
                  if (i > 0) gap,
                  TavliButtonRow(expand: true, children: [b]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
