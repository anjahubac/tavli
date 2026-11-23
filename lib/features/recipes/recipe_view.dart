import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/recipe_labels.dart';
import 'recipe_photo.dart';

/// Visina slike recepta iznad sadržaja.
const _photoHeight = 220.0;

/// Najveća širina sadržaja recepta, da redovi ostanu čitljivi.
const _readableWidth = 720.0;

/// Od ove širine sadržaja recept ima dve kolone (platno, računar): slika,
/// podaci, oznake i sastojci levo, priprema desno.
const _twoColumnsWidth = 640.0;

/// Širina leve kolone na računaru (platno: 380).
const _leftColumn = 380.0;

/// Sadržaj recepta: slika, porcije, sastojci po kategorijama, koraci.
/// Koristi se u detaljima, pregledu AI recepta i predlogu izmene.
class RecipeView extends StatelessWidget {
  const RecipeView(
    this.recipe, {
    super.key,
    this.photoBytes,
    this.showTitle = false,
    this.onEditLabels,
  });

  final Recipe recipe;

  /// Slika koja još nije sačuvana (pregled recepta iz slike).
  final Uint8List? photoBytes;
  final bool showTitle;

  /// Dugme „Izmeni oznake“; null = oznake se samo prikazuju.
  final VoidCallback? onEditLabels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= _twoColumnsWidth;
      final start = _start(context);
      final end = _preparation(context);
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TavliSpacing.medium,
          children: [...start, ...end],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TavliSpacing.large + TavliSpacing.small,
        children: [
          SizedBox(
            width: _leftColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.medium,
              children: start,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TavliSpacing.medium,
              children: end,
            ),
          ),
        ],
      );
    },
  );

  /// Slika, naslov, podaci, oznake i sastojci.
  List<Widget> _start(BuildContext context) {
    final theme = Theme.of(context);
    final path = recipe.imagePath;
    final bytes = photoBytes;
    final facts = [
      if (recipe.prepMinutes != null)
        _Fact(TavliIcons.timer, '${recipe.prepMinutes} min'),
      _Fact(TavliIcons.servings, servingsLabel(recipe.servings)),
    ];
    return [
      if (bytes != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(TavliRadius.card),
          child: Image.memory(
            bytes,
            height: _photoHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Slika recepta',
          ),
        )
      else if (path != null)
        RecipePhoto(path, height: _photoHeight)
      else
        const TavliThumbnail.banner(),
      if (showTitle) Text(recipe.title, style: theme.textTheme.headlineSmall),
      Wrap(
        spacing: TavliSpacing.large,
        runSpacing: TavliSpacing.small,
        children: facts,
      ),
      _Labels(recipe.labels, onEdit: onEditLabels),
      const TavliSectionHeader(
        'Sastojci',
        style: TavliSectionHeaderStyle.title,
      ),
      TavliCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (n, (category, items)) in groupByCategory(
              recipe.ingredients,
            ).indexed) ...[
              if (n > 0) const TavliDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TavliSpacing.medium + 2,
                  TavliSpacing.medium,
                  TavliSpacing.medium + 2,
                  0,
                ),
                child: TavliSectionHeader(category),
              ),
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const TavliDivider(),
                _IngredientRow(item),
              ],
            ],
          ],
        ),
      ),
    ];
  }

  /// Koraci pripreme i poreklo recepta.
  List<Widget> _preparation(BuildContext context) {
    final theme = Theme.of(context);
    final origin = recipe.answeredBy != null
        ? 'Napravio: ${recipe.answeredBy}'
        : recipe.source == RecipeSource.manual
        ? 'Ručno unet'
        : null;
    return [
      if (recipe.steps.isNotEmpty) ...[
        const TavliSectionHeader(
          'Priprema',
          style: TavliSectionHeaderStyle.title,
        ),
        for (final (n, step) in recipe.steps.indexed)
          _Step(number: n + 1, text: step),
      ],
      if (origin != null) Text(origin, style: theme.textTheme.bodySmall),
    ];
  }
}

/// Sastojak u kartici: naziv levo, količina i jedinica desno (kanvas).
class _IngredientRow extends StatelessWidget {
  const _IngredientRow(this.ingredient);

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final quantity = [
      if (ingredient.quantity != null) formatQuantity(ingredient.quantity!),
      ?ingredient.unit,
    ].join(' ');
    final note = ingredient.note;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TavliSpacing.medium + 2,
          vertical: TavliSpacing.small,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            spacing: TavliSpacing.medium,
            children: [
              Expanded(
                child: Text(
                  note == null ? ingredient.name : '${ingredient.name} ($note)',
                  style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (quantity.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: Text(
                    quantity,
                    textAlign: TextAlign.end,
                    style: t.bodyMedium?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Korak pripreme: broj u krugu boje teme i tekst (kanvas).
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TavliSpacing.medium - 2,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: Text(
                '$number',
                style: t.labelLarge?.copyWith(
                  color: c.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: Text(text, style: t.bodyLarge)),
      ],
    );
  }
}

/// Oznake recepta; nepoznata oznaka piše „Nije označeno“.
class _Labels extends StatelessWidget {
  const _Labels(this.labels, {this.onEdit});

  final RecipeLabels labels;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const unknown = 'Nije označeno';
    final meals = labels.mealSet;
    Widget row(String name, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$name: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: value,
              style: value == unknown
                  ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap: uz uvećan tekst dugme prelazi u novi red umesto preliva.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Oznake', style: theme.textTheme.titleMedium),
            if (onEdit != null)
              TavliButton.text(
                label: 'Izmeni oznake',
                glyph: TavliIcons.edit,
                onPressed: onEdit,
              ),
          ],
        ),
        row(
          'Obrok',
          meals.isEmpty
              ? unknown
              : [
                  for (final m in MealSuitability.values)
                    if (meals.contains(m)) m.label,
                ].join(', '),
        ),
        row('Težina', labels.weightValue?.label ?? unknown),
        row('Vrsta jela', labels.dishKindValue?.label ?? unknown),
      ],
    );
  }
}

/// Sadržaj ekrana ograničen na čitljivu širinu i sa skrolovanjem.
class ReadableScroll extends StatelessWidget {
  const ReadableScroll({
    super.key,
    required this.children,
    this.maxWidth = _readableWidth,
  });

  final List<Widget> children;

  /// Najveća širina sadržaja; ekran recepta na računaru koristi širu.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TavliSpacing.large),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Podatak o receptu sa ikonicom: porcije, vreme pripreme.
class _Fact extends StatelessWidget {
  const _Fact(this.glyph, this.text);

  final TavliIconData glyph;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TavliSpacing.small - 2,
      children: [
        TavliIcon(glyph, size: 18, color: muted),
        // Na uskom ekranu sa krupnim tekstom tekst prelazi u novi red.
        Flexible(
          child: Text(text, style: TextStyle(color: muted)),
        ),
      ],
    );
  }
}
