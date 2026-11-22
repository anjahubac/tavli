import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../../data/food_catalog_reader.dart';
import '../../../domain/food_preferences.dart';
import '../../../domain/recipe_format.dart';
import 'taste_labels.dart';
import 'tastes_providers.dart';
import 'tastes_screen.dart' show setFoodLiking;

/// Prečice za polje na računaru.
const _shortcuts = 'Enter: Volim · Shift+Enter: Ne volim';

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

/// Telefon: donji list „Dodaj namirnicu“ sa izborom Volim ili Ne volim,
/// pretragom kataloga i listom.
Future<void> showFoodPicker(
  BuildContext context, {
  required TavliLiking initial,
}) => showTavliSheet<void>(
  context,
  builder: (_) => _FoodPickerSheet(initial: initial),
);

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

/// Računar: polje „Dodaj namirnicu…“ u kartici Namirnice, sa predlozima
/// iz kataloga. Enter dodaje istaknutu namirnicu u Volim, Shift+Enter u
/// Ne volim; svaki predlog ima i oba dugmeta.
class InlineFoodSearch extends ConsumerStatefulWidget {
  const InlineFoodSearch({super.key, required this.enabled});

  final bool enabled;

  @override
  ConsumerState<InlineFoodSearch> createState() => _InlineFoodSearchState();
}

class _InlineFoodSearchState extends ConsumerState<InlineFoodSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(CatalogFoodEntry f, TavliLiking liking) async {
    _controller.clear();
    await setFoodLiking(ref, f.id, liking);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final foods = ref.watch(catalogFoodsProvider).value ?? const [];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final hintStyle = t.bodySmall?.copyWith(color: c.onSurfaceVariant);
    return RawAutocomplete<CatalogFoodEntry>(
      textEditingController: _controller,
      focusNode: _focus,
      displayStringForOption: (f) => capitalized(f.name),
      optionsBuilder: (value) => value.text.trim().isEmpty
          ? const []
          : _matching(foods, value.text).take(8),
      onSelected: (f) => _add(f, TavliLiking.like),
      fieldViewBuilder: (context, controller, focus, onSubmit) => Focus(
        // Shift+Enter: prva namirnica iz predloga ide u Ne volim.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              HardwareKeyboard.instance.isShiftPressed) {
            final first = _matching(foods, controller.text).firstOrNull;
            if (controller.text.trim().isNotEmpty && first != null) {
              unawaited(_add(first, TavliLiking.dislike));
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focus,
          enabled: widget.enabled,
          onSubmitted: (_) => onSubmit(),
          style: t.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Dodaj namirnicu…',
            filled: true,
            fillColor: TavliColors.of(context).bg,
            prefixIcon: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TavliSpacing.medium,
                  end: TavliSpacing.small,
                ),
                child: TavliIcon(
                  TavliIcons.search,
                  size: 18,
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
            // Prečice desno u polju, kao na platnu; uz krupan tekst ispod
            // polja, da polje ostane široko za unos.
            suffixIcon: largeText
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: TavliSpacing.medium,
                    ),
                    child: Text(_shortcuts, style: hintStyle),
                  ),
            suffixIconConstraints: const BoxConstraints(),
            helperText: largeText ? _shortcuts : null,
            helperStyle: hintStyle,
            helperMaxLines: 3,
          ),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TavliWidth.dialog),
          child: Material(
            elevation: 4,
            color: c.surface,
            borderRadius: BorderRadius.circular(TavliRadius.field),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final (i, f) in options.indexed)
                  Builder(
                    builder: (context) {
                      final highlighted =
                          AutocompleteHighlightedOption.of(context) == i;
                      return ColoredBox(
                        color: highlighted
                            ? c.primaryContainer
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: TavliSpacing.medium,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      capitalized(f.name),
                                      style: t.bodyLarge?.copyWith(
                                        color: c.onSurface,
                                      ),
                                    ),
                                    Text(
                                      capitalized(f.category),
                                      style: hintStyle,
                                    ),
                                  ],
                                ),
                              ),
                              TavliIconButton(
                                glyph: TavliIcons.like,
                                semanticLabel: 'Volim: ${capitalized(f.name)}',
                                onPressed: () => _add(f, TavliLiking.like),
                              ),
                              TavliIconButton(
                                glyph: TavliIcons.dislike,
                                semanticLabel:
                                    'Ne volim: ${capitalized(f.name)}',
                                onPressed: () => _add(f, TavliLiking.dislike),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
