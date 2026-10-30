import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import 'add_recipe_sheet.dart';
import 'recipe_detail_screen.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Od ove širine sadržaja lista i recept stoje jedno pored drugog.
const splitViewMinWidth = 840.0;

/// Tab "Recepti": lista sa pretragom; na širokom ekranu i izabrani recept.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= splitViewMinWidth;
        final selected = selectedId;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Recepti'),
            automaticallyImplyLeading: false,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddRecipeSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj recept'),
          ),
          body: wide
              ? Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: _RecipeList(selectedId: selected),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: selected == null
                          ? const _NothingSelected()
                          : RecipeDetailScreen(id: selected, embedded: true),
                    ),
                  ],
                )
              : _RecipeList(selectedId: selected),
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

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Izaberi recept',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _RecipeList extends ConsumerStatefulWidget {
  const _RecipeList({this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<_RecipeList> createState() => _RecipeListState();
}

class _RecipeListState extends ConsumerState<_RecipeList> {
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

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(recipeSearchProvider);
    return ref
        .watch(recipesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Message(
            icon: Icons.error_outline,
            title: 'Recepti nisu učitani.',
          ),
          data: (all) {
            if (all.isEmpty) {
              return const _Message(
                icon: Icons.menu_book_outlined,
                title: 'Još nema recepata',
                body: 'Dodaj prvi recept iz slike, po nazivu jela ili ručno.',
              );
            }
            final recipes = filterRecipes(all, query);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchBar(
                    controller: _search,
                    hintText: 'Pretraži recepte',
                    leading: const Icon(Icons.search),
                    onChanged: ref.read(recipeSearchProvider.notifier).set,
                    trailing: [
                      if (query.isNotEmpty)
                        IconButton(
                          tooltip: 'Obriši pretragu',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            ref.read(recipeSearchProvider.notifier).set('');
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: recipes.isEmpty
                      ? _Message(
                          icon: Icons.search_off,
                          title: 'Nema recepata za „${query.trim()}“.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: recipes.length,
                          itemBuilder: (context, i) => _RecipeTile(
                            recipes[i],
                            selected: recipes[i].id == widget.selectedId,
                          ),
                        ),
                ),
              ],
            );
          },
        );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile(this.recipe, {required this.selected});

  final Recipe recipe;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final path = recipe.imagePath;
    return ListTile(
      selected: selected,
      leading: SizedBox.square(
        dimension: 56,
        child: path == null
            ? Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).colorScheme.outline,
              )
            : RecipePhoto(path, size: 56),
      ),
      title: Text(recipe.title),
      subtitle: Text(
        [
          servingsLabel(recipe.servings),
          if (recipe.prepMinutes != null) '${recipe.prepMinutes} min',
        ].join(' · '),
      ),
      onTap: () => context.go('/recipes/${recipe.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
