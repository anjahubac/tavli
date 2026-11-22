import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/spoon_refresh.dart';
import '../../app/app_menu.dart';
import '../../app/tab_app_bar.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import 'add_recipe_sheet.dart';
import 'recipe_detail_screen.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Od ove širine sadržaja recepti su mreža u tri kolone sa zaglavljem
/// (platno, macOS i Windows · Recepti); uže je lista kartica kao na telefonu.
const _gridMinWidth = 840.0;

/// Polje za pretragu u zaglavlju, kao na platnu.
const _searchWidth = 300.0;

/// Kolone mreže recepata na računaru, kao na platnu; kolone su jednake i
/// rastu sa prozorom.
const _gridColumns = 3;

/// Prazan prostor ispod liste na telefonu, da plutajuće dugme ne pokrije
/// poslednji recept.
const _floatingButtonClearance = 88.0;

/// Tab "Recepti", po platnu. Telefon: pretraga, lista kartica u jednoj
/// koloni i plutajuće „Dodaj recept“. Računar: zaglavlje sa pretragom i
/// „Dodaj recept“ i mreža u tri kolone. Recept se otvara kao ceo ekran.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⌘N iz trake menija na macOS-u.
    ref.listen(menuRequestsProvider, (_, next) {
      if (next?.command == MenuCommand.newRecipe &&
          ModalRoute.isCurrentOf(context) == true) {
        unawaited(showAddRecipeSheet(context));
      }
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _gridMinWidth;
        return Scaffold(
          appBar: const TabAppBar(),
          floatingActionButton: wide
              ? null
              : TavliFloatingButton(
                  icon: Icons.add,
                  label: 'Dodaj recept',
                  onPressed: () => showAddRecipeSheet(context),
                ),
          body: _RecipesBody(wide: wide),
        );
      },
    );
  }
}

/// Ruta `/recipes/:id`: recept kao ceo ekran na svim platformama (platno
/// nema listu i detalj u Receptima).
class RecipeRoute extends StatelessWidget {
  const RecipeRoute({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => RecipeDetailScreen(id: id);
}

class _RecipesBody extends ConsumerStatefulWidget {
  const _RecipesBody({required this.wide});

  final bool wide;

  @override
  ConsumerState<_RecipesBody> createState() => _RecipesBodyState();
}

class _RecipesBodyState extends ConsumerState<_RecipesBody> {
  late final TextEditingController _search;

  // Pretraga prelazi iz liste u zaglavlje kad se prozor raširi; ključ čuva
  // isto polje, pa tekst i fokus ostaju.
  final _searchKey = GlobalKey();
  final _searchFocus = FocusNode(debugLabel: 'Pretraži recepte');

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(recipeSearchProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Osvežavanje traje samo dok se lista čita iz baze.
  Future<void> _refresh() async {
    ref.invalidate(recipesProvider);
    await ref.read(recipesProvider.future);
  }

  Widget _searchField() => TavliSearchField(
    key: _searchKey,
    hint: 'Pretraži recepte',
    controller: _search,
    focusNode: _searchFocus,
    onChanged: ref.read(recipeSearchProvider.notifier).set,
  );

  @override
  Widget build(BuildContext context) {
    // ⌘F iz trake menija na macOS-u.
    ref.listen(menuRequestsProvider, (_, next) {
      if (next?.command == MenuCommand.searchRecipes) {
        _searchFocus.requestFocus();
      }
    });
    final query = ref.watch(recipeSearchProvider);
    final content = ref
        .watch(recipesProvider)
        .when(
          loading: () => const TavliLoading(),
          error: (_, _) => const _ScrollableMessage(
            TavliEmptyState(
              icon: Icons.error_outline,
              title: 'Recepti nisu učitani.',
            ),
          ),
          data: (all) {
            if (all.isEmpty) {
              return const _ScrollableMessage(
                TavliEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Još nema recepata',
                  message:
                      'Dodaj prvi recept sa slike, po nazivu jela ili ručno.',
                ),
              );
            }
            final recipes = filterRecipes(all, query);
            if (recipes.isEmpty) {
              return _ScrollableMessage(
                TavliEmptyState(
                  icon: Icons.search_off,
                  title: 'Nema recepata za „${query.trim()}“.',
                ),
              );
            }
            if (!widget.wide) {
              return _RecipeList(recipes, onRefresh: _refresh);
            }
            return _RecipeGrid(recipes);
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

/// Vreme pa porcije, kao na platnu („75 min · 4 porcije“).
String _recipeFacts(Recipe recipe) => [
  if (recipe.prepMinutes != null) '${recipe.prepMinutes} min',
  servingsLabel(recipe.servings),
].join(' · ');

/// Naziv i vreme sa porcijama, kao na kartici recepta.
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

/// Lista kartica sa sličicom u jednoj koloni (telefon, platno · Recepti).
class _RecipeList extends StatelessWidget {
  const _RecipeList(this.recipes, {required this.onRefresh});

  final List<Recipe> recipes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SpoonRefresh(
      onRefresh: onRefresh,
      child: TavliCardGrid(
        // Položaj liste se pamti i kad se prozor na kratko raširi u mrežu.
        key: const PageStorageKey('recipes-list'),
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
          return _RecipeMenu(
            recipe,
            child: TavliCard(
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
            ),
          );
        },
      ),
    );
  }
}

/// Mreža recepata u tri kolone na širokom ekranu.
class _RecipeGrid extends StatelessWidget {
  const _RecipeGrid(this.recipes);

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return TavliCardGrid(
      key: const PageStorageKey('recipes-grid'),
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
        return _RecipeMenu(
          recipe,
          child: TavliCard(
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
          ),
        );
      },
    );
  }
}

/// Desni klik na recept (računar): iste radnje kao na ekranu recepta.
class _RecipeMenu extends StatelessWidget {
  const _RecipeMenu(this.recipe, {required this.child});

  final Recipe recipe;
  final Widget child;

  @override
  Widget build(BuildContext context) => TavliContextMenu(
    actions: [
      TavliMenuAction(
        'Otvori',
        onSelected: () => context.go('/recipes/${recipe.id}'),
      ),
      TavliMenuAction(
        'Izmeni',
        icon: Icons.edit_outlined,
        onSelected: () => context.go('/recipes/${recipe.id}/edit'),
      ),
    ],
    child: child,
  );
}

/// Prazno stanje koje se pomera kad uz veći tekst i navigaciju nema mesta.
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
