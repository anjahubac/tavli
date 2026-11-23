import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../../data/food_catalog_reader.dart';
import '../../../domain/food_preferences.dart';
import '../../../domain/recipe_format.dart';
import 'taste_labels.dart';
import 'tastes_providers.dart';
import 'tastes_screen.dart' show setFoodLiking;

/// Najviše toliko namirnica u rezultatima; ostalo se nalazi pretragom.
const _maxResults = 50;

/// Namirnice čiji naziv sadrži [query] (bez kvačica, mala slova).
List<CatalogFoodEntry> _matching(List<CatalogFoodEntry> foods, String query) {
  final q = normalizeForSearch(query);
  return [
    for (final f in foods)
      if (q.isEmpty || normalizeForSearch(f.name).contains(q)) f,
  ].take(_maxResults).toList();
}

TavliLiking _currentLiking(FoodPreferences? p, String id) => p == null
    ? TavliLiking.none
    : p.disliked.contains(id)
    ? TavliLiking.dislike
    : p.liked.contains(id)
    ? TavliLiking.like
    : TavliLiking.none;

/// „Dodaj namirnicu“ sa izborom Volim ili Ne volim, pretragom kataloga i
/// listom: na telefonu donji list, na računaru prozor.
Future<void> showFoodPicker(
  BuildContext context, {
  required TavliLiking initial,
  bool wide = false,
}) {
  if (!wide) {
    return showTavliSheet<void>(
      context,
      builder: (_) => _FoodPickerSheet(initial: initial),
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
        constraints: const BoxConstraints(maxWidth: TavliWidth.dialog),
        child: Padding(
          padding: const EdgeInsets.all(TavliSpacing.large),
          child: _FoodPickerSheet(initial: initial),
        ),
      ),
    ),
  );
}

class _FoodPickerSheet extends ConsumerStatefulWidget {
  const _FoodPickerSheet({required this.initial});

  final TavliLiking initial;

  @override
  ConsumerState<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends ConsumerState<_FoodPickerSheet> {
  late var _mode = widget.initial == TavliLiking.dislike
      ? TavliLiking.dislike
      : TavliLiking.like;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final foods = ref.watch(catalogFoodsProvider);
    final prefs = ref.watch(foodPreferencesProvider).value;
    final results = _matching(foods.value ?? const [], _query);

    Widget list() {
      if (foods.isLoading) return const TavliLoading();
      if (foods.value?.isEmpty ?? true) {
        return const TavliEmptyState(
          glyph: TavliIcons.search,
          title: 'Katalog namirnica još nije preuzet',
          message: 'Namirnice stižu sa servera kad je aplikacija na mreži.',
        );
      }
      if (results.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(TavliSpacing.large),
          child: Text(
            'Nema te namirnice u katalogu.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
          ),
        );
      }
      return TavliListGroup(
        children: [
          for (final f in results) _row(f, _currentLiking(prefs, f.id)),
        ],
      );
    }

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
                child: Semantics(
                  header: true,
                  child: Text(
                    'Dodaj namirnicu',
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: c.onSurface,
                    ),
                  ),
                ),
              ),
              TavliButton.text(
                label: 'Gotovo',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          TavliChoice<TavliLiking>.segmented(
            options: const [
              TavliOption(TavliLiking.like, 'Volim'),
              TavliOption(TavliLiking.dislike, 'Ne volim'),
            ],
            selected: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          TavliSearchField(
            hint: 'Pretraži namirnice',
            onChanged: (q) => setState(() => _query = q),
          ),
          Flexible(child: SingleChildScrollView(child: list())),
        ],
      ),
    );
  }

  Widget _row(CatalogFoodEntry f, TavliLiking current) {
    final same = current == _mode;
    final name = capitalized(f.name);
    final subtitle = switch (current) {
      TavliLiking.like => 'Već je u Volim',
      TavliLiking.dislike => 'Već je u Ne volim',
      TavliLiking.none => capitalized(f.category),
    };
    void pick() => setFoodLiking(ref, f.id, same ? TavliLiking.none : _mode);
    return TavliListRow(
      key: ValueKey(f.id),
      title: name,
      subtitle: subtitle,
      trailing: same
          ? TavliButton.text(label: 'Ukloni', onPressed: pick)
          : TavliButton.tonal(label: _mode.label, onPressed: pick),
    );
  }
}
