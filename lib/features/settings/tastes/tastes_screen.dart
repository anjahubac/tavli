import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../../data/food_catalog_reader.dart';
import '../../../domain/allergen_group.dart';
import '../../../domain/cuisine_preferences.dart';
import '../../../domain/dish_kind_preferences.dart';
import '../../../domain/food_preferences.dart';
import '../../../domain/recipe.dart';
import '../../../domain/recipe_labels.dart';
import '../../../providers.dart';
import '../../recipes/recipe_photo.dart';
import '../settings_page.dart';
import 'favorite_recipe_picker.dart';
import 'food_picker.dart';
import 'taste_labels.dart';
import 'tastes_providers.dart';

/// Ukusi i alergeni (008, D3-004/D3-009/D3-011), varijanta A sa platna:
/// alergeni, vrste jela, kuhinje, omiljeni recepti, namirnice i deljenje
/// sa planom domaćinstva. Svaka promena se odmah čuva (drift + red za
/// slanje); deljenje se menja samo na mreži.
///
/// Telefon: odeljci jedan ispod drugog. Širok ekran: dve kolone kao na
/// platnu za macOS.
class TastesScreen extends ConsumerWidget {
  const TastesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWideSettings(context);
    return SettingsPage(
      title: 'Ukusi i alergeni',
      backLabel: 'Profil',
      fallbackLocation: '/profile',
      children: [
        const _Intro(),
        if (wide)
          const SettingsColumns(
            start: [_AllergensSection(wide: true), _SharingSection()],
            end: [
              _KindsAndCuisinesSection(),
              _FoodsSection(wide: true),
              _FavoritesSection(wide: true),
            ],
          )
        else ...const [
          _AllergensSection(wide: false),
          _DishKindsSection(),
          _CuisinesSection(),
          _FavoritesSection(wide: false),
          _FoodsSection(wide: false),
          _SharingSection(),
        ],
      ],
    );
  }
}

TextStyle? _helpStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Text(
    'Tavli ovo koristi da predloži jela koja ti prijaju. '
    'Promene se čuvaju same.',
    style: _helpStyle(context),
  );
}

/// Naslov odeljka, opciono objašnjenje ispod i sadržaj.
class _TasteSection extends StatelessWidget {
  const _TasteSection({
    required this.title,
    required this.child,
    this.trailing,
    this.help,
  });

  final String title;
  final Widget? trailing;
  final Widget? help;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TavliSpacing.small,
    children: [
      TavliSectionHeader(title, trailing: trailing),
      ?help,
      child,
    ],
  );
}

/// Kratak tekst desno od naslova odeljka („Izabrano: 2“).
class _HeaderNote extends StatelessWidget {
  const _HeaderNote(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: strong ? c.primary : c.onSurfaceVariant),
    );
  }
}

/// Bela kartica sa ivicom, kao odeljci na računaru.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TavliCard(child: child);
}

// ---------------------------------------------------------------------------
// Alergeni

class _AllergensSection extends ConsumerWidget {
  const _AllergensSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(allergenSelectionProvider);
    final selected = selection.value ?? const <AllergenGroup>{};
    final enabled = selection.hasValue;
    Future<void> toggle(AllergenGroup group, bool on) async {
      final repo = ref.read(allergenRepositoryProvider);
      final current = await repo.getSelection();
      await repo.saveSelection(
        on ? {...current, group} : current.difference({group}),
      );
    }

    final help = Text(
      'Jela sa ovim sastojcima ne ulaze u plan. Izbor vidiš samo ti.',
      style: _helpStyle(context),
    );
    final summary = _HeaderNote(
      selected.isEmpty ? 'Nijedan' : 'Izabrano: ${selected.length}',
      strong: true,
    );
    if (!wide) {
      return _TasteSection(
        title: 'Alergeni',
        trailing: summary,
        help: help,
        child: TavliChipWrap(
          children: [
            for (final (group, label, icon) in allergenChoices)
              TavliToggleChip(
                label: label,
                icon: icon,
                selected: selected.contains(group),
                onChanged: enabled ? (on) => toggle(group, on) : null,
              ),
          ],
        ),
      );
    }
    final tiles = [
      for (final (group, label, icon) in allergenChoices)
        TavliToggleChip.tile(
          label: label,
          icon: icon,
          selected: selected.contains(group),
          onChanged: enabled ? (on) => toggle(group, on) : null,
        ),
    ];
    return _TasteSection(
      title: 'Alergeni',
      trailing: summary,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.small,
          children: [
            help,
            for (var i = 0; i < tiles.length; i += 2)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TavliSpacing.small,
                  children: [
                    Expanded(child: tiles[i]),
                    Expanded(
                      child: i + 1 < tiles.length
                          ? tiles[i + 1]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vrste jela i kuhinje

TavliLiking _likingOf<T>(T value, Set<T> liked, Set<T> disliked) =>
    disliked.contains(value)
    ? TavliLiking.dislike
    : liked.contains(value)
    ? TavliLiking.like
    : TavliLiking.none;

/// Novi skupovi „Volim“ i „Ne volim“ posle izbora [liking] za [value].
(Set<T>, Set<T>) _withLiking<T>(
  T value,
  TavliLiking liking,
  Set<T> liked,
  Set<T> disliked,
) => (
  {...liked.where((v) => v != value), if (liking == TavliLiking.like) value},
  {
    ...disliked.where((v) => v != value),
    if (liking == TavliLiking.dislike) value,
  },
);

Future<void> _setDishKind(
  WidgetRef ref,
  DishKind kind,
  TavliLiking liking,
) async {
  final repo = ref.read(tasteProfileRepositoryProvider);
  final p = await repo.getDishPreferences();
  final (liked, disliked) = _withLiking(kind, liking, p.liked, p.disliked);
  await repo.saveDishPreferences(
    DishKindPreferences(liked: liked, disliked: disliked),
  );
}

Future<void> _setCuisine(
  WidgetRef ref,
  Cuisine cuisine,
  TavliLiking liking,
) async {
  final repo = ref.read(tasteProfileRepositoryProvider);
  final p = await repo.getCuisinePreferences();
  final (liked, disliked) = _withLiking(cuisine, liking, p.liked, p.disliked);
  await repo.saveCuisinePreferences(
    CuisinePreferences(liked: liked, disliked: disliked),
  );
}

class _DishKindChips extends ConsumerWidget {
  const _DishKindChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(dishPreferencesProvider);
    final p = prefs.value;
    return TavliChipWrap(
      children: [
        for (final kind in DishKind.values)
          TavliLikingChip(
            label: kind.label,
            liking: p == null
                ? TavliLiking.none
                : _likingOf(kind, p.liked, p.disliked),
            onChanged: p == null ? null : (l) => _setDishKind(ref, kind, l),
          ),
      ],
    );
  }
}

class _CuisineChips extends ConsumerWidget {
  const _CuisineChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(cuisinePreferencesProvider);
    final p = prefs.value;
    return TavliChipWrap(
      children: [
        for (final cuisine in Cuisine.values)
          TavliLikingChip(
            label: cuisineLabel(cuisine),
            liking: p == null
                ? TavliLiking.none
                : _likingOf(cuisine, p.liked, p.disliked),
            onChanged: p == null ? null : (l) => _setCuisine(ref, cuisine, l),
          ),
      ],
    );
  }
}

/// „Dodirni jednom za Volim, još jednom za Ne volim.“
class _LikingHelp extends StatelessWidget {
  const _LikingHelp();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dislike = TavliStatusColors.of(context).dislike.foreground;
    const bold = FontWeight.w700;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Dodirni jednom za '),
          TextSpan(
            text: 'Volim',
            style: TextStyle(fontWeight: bold, color: c.onPrimaryContainer),
          ),
          const TextSpan(text: ', još jednom za '),
          TextSpan(
            text: 'Ne volim',
            style: TextStyle(fontWeight: bold, color: dislike),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      style: _helpStyle(context),
    );
  }
}

class _DishKindsSection extends StatelessWidget {
  const _DishKindsSection();

  @override
  Widget build(BuildContext context) => const _TasteSection(
    title: 'Vrste jela',
    help: _LikingHelp(),
    child: _DishKindChips(),
  );
}

class _CuisinesSection extends StatelessWidget {
  const _CuisinesSection();

  @override
  Widget build(BuildContext context) =>
      const _TasteSection(title: 'Kuhinje', child: _CuisineChips());
}

/// Računar: vrste jela i kuhinje u jednoj kartici.
class _KindsAndCuisinesSection extends StatelessWidget {
  const _KindsAndCuisinesSection();

  @override
  Widget build(BuildContext context) {
    const hint = 'Klik: Volim · još jednom: Ne volim';
    // Uz krupan tekst napomena ne staje pored naslova, pa ide u karticu.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return _TasteSection(
      title: 'Vrste jela i kuhinje',
      trailing: largeText
          ? null
          : Flexible(
              child: Text(
                hint,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.medium,
          children: [
            if (largeText) Text(hint, style: _helpStyle(context)),
            const _DishKindChips(),
            const TavliDivider(),
            const _CuisineChips(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Omiljeni recepti

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRecipesProvider).value ?? const [];
    void add() => showFavoriteRecipePicker(context, wide: wide);
    Widget tile(int i, Recipe r, {required bool expand}) => TavliRecipeTile(
      key: ValueKey(r.id),
      title: r.title,
      tintIndex: i,
      expand: expand,
      photo: switch (r.imagePath) {
        final path? => RecipePhoto(path),
        null => null,
      },
      onTap: () => context.go('/recipes/${r.id}'),
    );
    if (!wide) {
      return _TasteSection(
        title: 'Omiljeni recepti',
        trailing: _HeaderNote('${favorites.length}'),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.small,
              children: [
                TavliAddTile(label: 'Dodaj', onTap: add),
                for (final (i, r) in favorites.indexed)
                  tile(i, r, expand: false),
              ],
            ),
          ),
        ),
      );
    }
    const columns = 3;
    return _TasteSection(
      title: 'Omiljeni recepti',
      trailing: TavliButton.text(
        label: 'Dodaj',
        glyph: TavliIcons.add,
        onPressed: add,
      ),
      child: favorites.isEmpty
          ? Text('Još nema omiljenih recepata.', style: _helpStyle(context))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.small,
              children: [
                for (var i = 0; i < favorites.length; i += columns)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: TavliSpacing.small,
                      children: [
                        for (var j = i; j < i + columns; j++)
                          Expanded(
                            child: j < favorites.length
                                ? tile(j, favorites[j], expand: true)
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Namirnice

/// Čuva [liking] za namirnicu [foodId] (ništa uklanja izbor).
Future<void> setFoodLiking(
  WidgetRef ref,
  String foodId,
  TavliLiking liking,
) async {
  final repo = ref.read(tasteProfileRepositoryProvider);
  final p = await repo.getFoodPreferences();
  final (liked, disliked) = _withLiking(foodId, liking, p.liked, p.disliked);
  await repo.saveFoodPreferences(
    FoodPreferences(liked: liked, disliked: disliked),
  );
}

class _FoodsSection extends ConsumerWidget {
  const _FoodsSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(foodPreferencesProvider).value;
    final foods = ref.watch(catalogFoodsProvider).value ?? const [];
    final byId = {for (final f in foods) f.id: f};
    // Namirnica koje više nema u katalogu ostaje sačuvana, ali se ne
    // prikazuje (nema naziv).
    List<CatalogFoodEntry> named(Set<String> ids) =>
        [for (final id in ids) ?byId[id]]
          ..sort((a, b) => a.name.compareTo(b.name));
    final liked = named(prefs?.liked ?? const {});
    final disliked = named(prefs?.disliked ?? const {});
    final enabled = prefs != null;

    Widget chips(List<CatalogFoodEntry> list, TavliLiking liking) =>
        TavliChipWrap(
          children: [
            for (final f in list)
              TavliRemovableChip(
                key: ValueKey(f.id),
                label: capitalized(f.name),
                liking: liking,
                onRemove: enabled
                    ? () => setFoodLiking(ref, f.id, TavliLiking.none)
                    : null,
              ),
            if (!wide)
              TavliAddChip(
                label: 'Dodaj',
                onTap: enabled
                    ? () => showFoodPicker(context, initial: liking)
                    : null,
              ),
          ],
        );

    final help = Text(
      'Ono što ne voliš ne zabranjuje jelo, samo ga ređe predlažemo.',
      style: _helpStyle(context),
    );
    const likeRow = _FoodGroupLabel(liking: TavliLiking.like);
    const dislikeRow = _FoodGroupLabel(liking: TavliLiking.dislike);
    if (!wide) {
      return _TasteSection(
        title: 'Namirnice',
        help: help,
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TavliSpacing.small,
            children: [
              likeRow,
              chips(liked, TavliLiking.like),
              const TavliDivider(),
              dislikeRow,
              chips(disliked, TavliLiking.dislike),
            ],
          ),
        ),
      );
    }
    return _TasteSection(
      title: 'Namirnice',
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TavliSpacing.medium,
          children: [
            InlineFoodSearch(enabled: enabled),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                for (final (label, list, liking) in [
                  (likeRow, liked, TavliLiking.like),
                  (dislikeRow, disliked, TavliLiking.dislike),
                ])
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: TavliSpacing.medium,
                          top: TavliSpacing.medium,
                        ),
                        child: label,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: TavliSpacing.small,
                        ),
                        child: list.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: TavliSpacing.medium,
                                ),
                                child: Text('—', style: _helpStyle(context)),
                              )
                            : chips(list, liking),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// „♡ Volim“ ili „⊘ Ne volim“ iznad čipova namirnica.
class _FoodGroupLabel extends StatelessWidget {
  const _FoodGroupLabel({required this.liking});

  final TavliLiking liking;

  @override
  Widget build(BuildContext context) {
    final color = liking == TavliLiking.like
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : TavliStatusColors.of(context).dislike.foreground;
    return Row(
      spacing: TavliSpacing.small,
      children: [
        TavliIcon(likingIcon(liking)!, size: 16, color: color),
        Flexible(
          child: Text(
            liking.label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Plan domaćinstva

class _SharingSection extends ConsumerWidget {
  const _SharingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharing = ref.watch(planningSharingProvider);
    final value = sharing.value?.preferences ?? false;
    final ready = sharing.hasValue && !sharing.isLoading;

    Future<void> change(bool enabled) async {
      if (enabled &&
          !await showTavliConfirm(
            context,
            title: 'Deli ukuse i omiljene?',
            message:
                'Tvoji ukusi i omiljeni recepti pomažu kad Tavli pravi plan '
                'za celo domaćinstvo. Za taj plan šalju se AI servisu '
                '(Gemini, Groq ili OpenRouter), bez tvog imena. Ostali '
                'članovi ne vide tvoje izbore. Deljenje možeš da isključiš '
                'kad god želiš.',
            confirmLabel: 'Deli',
          )) {
        return;
      }
      final failure = await ref
          .read(planningSharingProvider.notifier)
          .setPreferences(enabled);
      if (failure == null || !context.mounted) return;
      showTavliMessage(context, switch (failure) {
        SharingFailure.offline =>
          'Nema veze sa internetom. Deljenje nije promenjeno.',
        SharingFailure.changedElsewhere =>
          'Deljenje je promenjeno na drugom uređaju. Proveri i pokušaj ponovo.',
        SharingFailure.failed => 'Deljenje nije promenjeno. Pokušaj ponovo.',
      });
    }

    return _TasteSection(
      title: 'Plan domaćinstva',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TavliSpacing.small,
        children: [
          TavliListGroup(
            children: [
              TavliSwitchRow(
                title: 'Deli ukuse i omiljene',
                subtitle:
                    'Pomažu kad Tavli pravi plan za sve. Ostali članovi ne '
                    'vide tvoje izbore.',
                value: value,
                onChanged: ready ? change : null,
              ),
            ],
          ),
          if (sharing.hasError && !sharing.isLoading)
            TavliNotice(
              tone: TavliNoticeTone.warning,
              message:
                  'Deljenje se menja samo uz internet. Trenutno ne možemo '
                  'da proverimo podešavanje.',
              linkLabel: 'Pokušaj ponovo',
              onLink: () => ref.invalidate(planningSharingProvider),
            ),
          const _AllergenAssurance(),
        ],
      ),
    );
  }
}

/// Katanac i rečenica da se alergeni uvek poštuju.
class _AllergenAssurance extends StatelessWidget {
  const _AllergenAssurance();

  @override
  Widget build(BuildContext context) {
    final style = _helpStyle(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavliSpacing.small / 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TavliSpacing.small,
        children: [
          TavliIcon(TavliIcons.lock, size: 16, color: style?.color),
          Expanded(
            child: Text(
              'Alergene plan uvek poštuje, i kad je deljenje isključeno. '
              'Niko ih drugi ne vidi.',
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
