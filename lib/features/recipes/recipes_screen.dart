import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/spoon_refresh.dart';
import '../../app/tab_app_bar.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import 'add_recipe_sheet.dart';
import 'recipe_detail_screen.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Od ove širine sadržaja recepti su mreža u tri kolone, a izabran recept
/// stoji pored liste.
const splitViewMinWidth = 840.0;

/// Širina liste pored izabranog recepta i polja za pretragu u zaglavlju.
const _listWidth = 360.0;
const _searchWidth = 300.0;

/// Kolone mreže recepata na računaru.
const _gridColumns = 3;

/// Prazan prostor ispod liste na telefonu, da plutajuće dugme ne pokrije
/// poslednji recept.
const _floatingButtonClearance = 88.0;

/// Tab "Recepti". Telefon: pretraga, lista kartica i plutajuće „Dodaj
/// recept“. Široko: zaglavlje sa pretragom i „Dodaj recept“, mreža u tri
/// kolone, a izabran recept pored liste.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= splitViewMinWidth;
        return Scaffold(
          appBar: const TabAppBar(),
          floatingActionButton: wide
              ? null
              : TavliFloatingButton(
                  icon: Icons.add,
                  label: 'Dodaj recept',
                  onPressed: () => showAddRecipeSheet(context),
                ),
          body: _RecipesBody(selectedId: selectedId, wide: wide),
        );
      },
    );
  }
}

/// Ruta `/recipes/:id`: podeljen prikaz na širokom ekranu, inače ceo ekran.
class RecipeRoute extends StatelessWidget {
  const RecipeRoute({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= splitViewMinWidth
          ? RecipesScreen(selectedId: id)
          : RecipeDetailScreen(id: id),
    );
  }
}

class _RecipesBody extends ConsumerStatefulWidget {
  const _RecipesBody({required this.selectedId, required this.wide});

  final String? selectedId;
  final bool wide;

  @override
  ConsumerState<_RecipesBody> createState() => _RecipesBodyState();
}

class _RecipesBodyState extends ConsumerState<_RecipesBody> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(recipeSearchProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Osvežavanje traje samo dok se lista čita iz baze.
  Future<void> _refresh() async {
    ref.invalidate(recipesProvider);
    await ref.read(recipesProvider.future);
  }

  Widget _searchField() => TavliSearchField(
    hint: 'Pretraži recepte',
    controller: _search,
    onChanged: ref.read(recipeSearchProvider.notifier).set,
  );

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(recipeSearchProvider);
    final selected = widget.selectedId;
    final content = ref
        .watch(recipesProvider)
        .when(
          loading: () => const TavliLoading(),
          error: (_, _) => const TavliEmptyState(
            icon: Icons.error_outline,
            title: 'Recepti nisu učitani.',
          ),
          data: (all) {
            if (all.isEmpty) {
              return const TavliEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Još nema recepata',
                message:
                    'Dodaj prvi recept sa slike, po nazivu jela ili ručno.',
              );
            }
            final recipes = filterRecipes(all, query);
            if (recipes.isEmpty) {
              return TavliEmptyState(
                icon: Icons.search_off,
                title: 'Nema recepata za „${query.trim()}“.',
              );
            }
            if (!widget.wide) {
              return _RecipeList(
                recipes,
                selectedId: selected,
                onRefresh: _refresh,
              );
            }
            if (selected == null) return _RecipeGrid(recipes);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _listWidth,
                  child: _RecipeList(
                    recipes,
                    selectedId: selected,
                    onRefresh: _refresh,
                  ),
                ),
                const TavliDivider(vertical: true),
                Expanded(
                  child: RecipeDetailScreen(id: selected, embedded: true),
                ),
              ],
            );
          },
        );

    if (!widget.wide) {
      final hasRecipes = ref.watch(recipesProvider).value?.isNotEmpty ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasRecipes)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TavliSpacing.large,
                TavliSpacing.small,
                TavliSpacing.large,
                TavliSpacing.medium,
              ),
              child: _searchField(),
            ),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TavliSpacing.large,
            TavliSpacing.large,
            TavliSpacing.large,
            TavliSpacing.medium,
          ),
          child: TavliPageHeader(
            title: 'Recepti',
            actions: [
              SizedBox(width: _searchWidth, child: _searchField()),
              TavliButton.primary(
                label: 'Dodaj recept',
                icon: Icons.add,
                onPressed: () => showAddRecipeSheet(context),
              ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

String _recipeFacts(Recipe recipe) => [
  servingsLabel(recipe.servings),
  if (recipe.prepMinutes != null) '${recipe.prepMinutes} min',
].join(' · ');

/// Naziv i porcije sa vremenom, kao na kartici recepta.
class _RecipeTitle extends StatelessWidget {
  const _RecipeTitle(this.recipe);

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(recipe.title, style: t.titleMedium),
        Text(
          _recipeFacts(recipe),
          style: t.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Lista kartica sa sličicom (telefon, i lista pored izabranog recepta).
class _RecipeList extends StatelessWidget {
  const _RecipeList(
    this.recipes, {
    required this.selectedId,
    required this.onRefresh,
  });

  final List<Recipe> recipes;
  final String? selectedId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SpoonRefresh(
      onRefresh: onRefresh,
      child: TavliCardGrid(
        columns: _listColumns(context),
        physics: const AlwaysScrollableScrollPhysics(),
        spacing: TavliSpacing.small,
        padding: const EdgeInsets.fromLTRB(
          TavliSpacing.large,
          0,
          TavliSpacing.large,
          _floatingButtonClearance,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, i) {
          final recipe = recipes[i];
          final path = recipe.imagePath;
          return TavliCard(
            selected: recipe.id == selectedId,
            padding: const EdgeInsets.all(TavliSpacing.small),
            onTap: () => context.go('/recipes/${recipe.id}'),
            child: Row(
              children: [
                TavliThumbnail.row(
                  tintIndex: i,
                  icon: Icons.soup_kitchen_outlined,
                  photo: path == null ? null : RecipePhoto(path),
                ),
                const SizedBox(width: TavliSpacing.medium),
                Expanded(child: _RecipeTitle(recipe)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Na tabletu u uspravnom položaju dve kolone kartica, da red ne ide preko
/// cele širine; uz krupan tekst jedna.
int _listColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
  return width >= 600 && !largeText ? 2 : 1;
}

/// Mreža recepata u tri kolone na širokom ekranu.
class _RecipeGrid extends StatelessWidget {
  const _RecipeGrid(this.recipes);

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return TavliCardGrid(
      columns: _gridColumns,
      padding: const EdgeInsets.fromLTRB(
        TavliSpacing.large,
        0,
        TavliSpacing.large,
        TavliSpacing.large,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, i) {
        final recipe = recipes[i];
        final path = recipe.imagePath;
        return TavliCard(
          padding: EdgeInsets.zero,
          onTap: () => context.go('/recipes/${recipe.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TavliThumbnail.cardTop(
                tintIndex: i,
                icon: Icons.soup_kitchen_outlined,
                photo: path == null ? null : RecipePhoto(path),
              ),
              Padding(
                padding: const EdgeInsets.all(TavliSpacing.medium),
                child: _RecipeTitle(recipe),
              ),
            ],
          ),
        );
      },
    );
  }
}
