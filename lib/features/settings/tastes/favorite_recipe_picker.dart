import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../../account/auth_gateway.dart';
import '../../../domain/recipe.dart';
import '../../../domain/recipe_format.dart';
import '../../../providers.dart';
import '../../recipes/recipe_photo.dart';
import '../../recipes/recipe_providers.dart';
import 'tastes_providers.dart';

/// Vreme pa porcije, kao na platnu („75 min · 4 porcije“).
String _facts(Recipe r) => [
  if (r.prepMinutes != null) '${r.prepMinutes} min',
  servingsLabel(r.servings),
].join(' · ');

/// Izbor omiljenih recepata: donji list na telefonu, dijalog sa mrežom na
/// širokom ekranu. Dodir na recept ga dodaje ili uklanja odmah.
Future<void> showFavoriteRecipePicker(
  BuildContext context, {
  required bool wide,
}) {
  if (!wide) {
    return showTavliSheet<void>(
      context,
      builder: (_) => const _FavoritePicker(wide: false),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.card),
      ),
      insetPadding: const EdgeInsets.all(TavliSpacing.large),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: TavliWidth.panel,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: const _FavoritePicker(wide: true),
      ),
    ),
  );
}

class _FavoritePicker extends ConsumerStatefulWidget {
  const _FavoritePicker({required this.wide});

  final bool wide;

  @override
  ConsumerState<_FavoritePicker> createState() => _FavoritePickerState();
}

class _FavoritePickerState extends ConsumerState<_FavoritePicker> {
  var _query = '';
  var _onlyFavorites = false;

  Future<void> _toggle(Recipe r, bool favorite) async {
    try {
      await ref
          .read(favoriteRepositoryProvider)
          .setFavorite(r.id, isFavorite: !favorite);
    } on Unavailable {
      if (mounted) showTavliMessage(context, 'Recept više nije dostupan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final recipes = ref.watch(recipesProvider);
    final favorites = ref.watch(favoriteRecipeIdsProvider).value ?? const {};
    final q = normalizeForSearch(_query);
    final shown = [
      for (final r in recipes.value ?? const <Recipe>[])
        if ((q.isEmpty || normalizeForSearch(r.title).contains(q)) &&
            (!_onlyFavorites || favorites.contains(r.id)))
          r,
    ];
    final count = 'Izabrano: ${favorites.length}';
    final muted = t.bodyMedium?.copyWith(color: c.onSurfaceVariant);

    Widget body() {
      if (recipes.isLoading) return const TavliLoading();
      if (recipes.value?.isEmpty ?? true) {
        return const TavliEmptyState(
          glyph: TavliIcons.recipes,
          title: 'Još nema recepata',
          message: 'Dodaj recept u Receptima, pa ga označi kao omiljeni.',
        );
      }
      if (shown.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(TavliSpacing.large),
          child: Text(
            'Nema recepta sa tim imenom.',
            textAlign: TextAlign.center,
            style: muted,
          ),
        );
      }
      return widget.wide ? _grid(shown, favorites) : _list(shown, favorites);
    }

    final title = Semantics(
      header: true,
      child: Text(
        'Omiljeni recepti',
        style: t.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: c.onSurface,
        ),
      ),
    );
    final search = TavliSearchField(
      hint: 'Pretraži recepte',
      onChanged: (v) => setState(() => _query = v),
    );

    if (!widget.wide) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.medium,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Text(count, style: muted),
                    ],
                  ),
                ),
                TavliButton.text(
                  label: 'Gotovo',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            search,
            const TavliSectionHeader('Moji recepti'),
            Flexible(child: SingleChildScrollView(child: body())),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TavliSpacing.large,
            TavliSpacing.large,
            TavliSpacing.small,
            TavliSpacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Text(
                      'Klikni recept da ga dodaš ili ukloniš. $count.',
                      style: muted,
                    ),
                  ],
                ),
              ),
              TavliIconButton(
                glyph: TavliIcons.close,
                semanticLabel: 'Zatvori',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TavliSpacing.large),
          child: Row(
            spacing: TavliSpacing.small,
            children: [
              Expanded(child: search),
              TavliToggleChip(
                label: 'Samo omiljeni',
                icon: TavliIcons.like,
                selected: _onlyFavorites,
                onChanged: (v) => setState(() => _onlyFavorites = v),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TavliSpacing.large),
            child: body(),
          ),
        ),
        const TavliDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TavliSpacing.large,
            vertical: TavliSpacing.medium,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TavliButton.primary(
              label: 'Gotovo',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(List<Recipe> recipes, Set<String> favorites) => TavliListGroup(
    children: [
      for (final (i, r) in recipes.indexed)
        Builder(
          builder: (context) {
            final on = favorites.contains(r.id);
            return TavliListRow(
              key: ValueKey(r.id),
              title: r.title,
              subtitle: _facts(r),
              leading: TavliThumbnail.row(
                tintIndex: i,
                icon: Icons.soup_kitchen_outlined,
                photo: switch (r.imagePath) {
                  final path? => RecipePhoto(path),
                  null => null,
                },
              ),
              onTap: () => _toggle(r, on),
              trailing: TavliIconButton(
                glyph: TavliIcons.like,
                selected: on,
                semanticLabel: on
                    ? 'Ukloni iz omiljenih: ${r.title}'
                    : 'Dodaj u omiljene: ${r.title}',
                onPressed: () => _toggle(r, on),
              ),
            );
          },
        ),
    ],
  );

  Widget _grid(List<Recipe> recipes, Set<String> favorites) {
    const columns = 3;
    Widget card(int i) {
      final r = recipes[i];
      final on = favorites.contains(r.id);
      final t = Theme.of(context).textTheme;
      final c = Theme.of(context).colorScheme;
      return Semantics(
        toggled: on,
        child: TavliCard(
          key: ValueKey(r.id),
          selected: on,
          padding: EdgeInsets.zero,
          onTap: () => _toggle(r, on),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  TavliThumbnail.cardTop(
                    tintIndex: i,
                    icon: Icons.soup_kitchen_outlined,
                    photo: switch (r.imagePath) {
                      final path? => RecipePhoto(path),
                      null => null,
                    },
                  ),
                  PositionedDirectional(
                    top: TavliSpacing.small,
                    end: TavliSpacing.small,
                    child: TavliIcon(
                      TavliIcons.like,
                      size: 18,
                      color: on ? c.primary : c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(TavliSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: t.labelLarge?.copyWith(color: c.onSurface),
                    ),
                    Text(
                      _facts(r),
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.small,
      children: [
        for (var i = 0; i < recipes.length; i += columns)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.small,
              children: [
                for (var j = i; j < i + columns; j++)
                  Expanded(
                    child: j < recipes.length
                        ? card(j)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
