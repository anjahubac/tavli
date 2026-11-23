import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/shopping_source.dart';
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
              icon: Icons.error_outline,
              title: 'Recept nije učitan.',
            ),
          ),
          data: (recipe) => recipe == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const TavliEmptyState(
                    icon: Icons.menu_book_outlined,
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
            icon: Icons.edit_outlined,
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
          children: [
            Semantics(
              header: true,
              child: Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: TavliSpacing.medium),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: TavliButtonRow(
                  expand: true,
                  children: [
                    TavliButton.primary(
                      label: 'Kuvaj',
                      glyph: TavliIcons.cook,
                      onPressed: () =>
                          context.push('/cook/recipe/${recipe.id}'),
                    ),
                    TavliButton.secondary(
                      label: 'Proveri sastojke',
                      icon: Icons.checklist,
                      onPressed: () => showIngredientReview(
                        context,
                        snapshot: RecipeSnapshot.fromRecipe(recipe),
                        originKey: 'recipe:${recipe.id}',
                        recipeId: recipe.id,
                      ),
                    ),
                  ],
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
