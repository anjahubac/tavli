import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/shopping_source.dart';
import 'ingredient_review_sheet.dart';
import 'keep_screen_on.dart';
import 'recipe_providers.dart';
import 'recipe_view.dart';
import 'versions_sheet.dart';

/// Detalji recepta. [embedded] je desni deo podeljenog prikaza (bez "nazad").
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({
    super.key,
    required this.id,
    this.embedded = false,
  });

  final String id;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recipeProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !embedded),
            body: const TavliLoading(),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !embedded),
            body: const TavliEmptyState(
              icon: Icons.error_outline,
              title: 'Recept nije učitan.',
            ),
          ),
          data: (recipe) => recipe == null
              ? Scaffold(
                  appBar: AppBar(automaticallyImplyLeading: !embedded),
                  body: TavliEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: embedded
                        ? 'Izaberi recept'
                        : 'Recept više ne postoji.',
                  ),
                )
              : _Detail(recipe: recipe, embedded: embedded),
        );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.recipe, required this.embedded});

  final Recipe recipe;
  final bool embedded;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasVersions =
        ref.watch(recipeVersionsProvider(recipe.id)).value?.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
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
              child: TavliButton.secondary(
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
            const SizedBox(height: TavliSpacing.large),
            RecipeView(recipe),
          ],
        ),
      ),
    );
  }
}
