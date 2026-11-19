import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import '../../domain/recipe_labels.dart';
import 'recipe_photo.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = recipe.imagePath;
    final bytes = photoBytes;
    final origin = recipe.answeredBy != null
        ? 'Napravio: ${recipe.answeredBy}'
        : recipe.source == RecipeSource.manual
        ? 'Ručno unet'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Slika recepta',
            ),
          )
        else if (path != null)
          RecipePhoto(path, height: 220),
        if (bytes != null || path != null) const SizedBox(height: 16),
        if (showTitle) ...[
          Text(recipe.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.people_outline, size: 18),
              label: Text(servingsLabel(recipe.servings)),
            ),
            if (recipe.prepMinutes != null)
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text('${recipe.prepMinutes} min'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Labels(recipe.labels, onEdit: onEditLabels),
        const SizedBox(height: 16),
        Text('Sastojci', style: theme.textTheme.titleMedium),
        for (final (category, items) in groupByCategory(
          recipe.ingredients,
        )) ...[
          const SizedBox(height: 12),
          Text(
            category,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• ${ingredientLine(i)}'),
            ),
        ],
        const SizedBox(height: 20),
        Text('Priprema', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (recipe.steps.isEmpty)
          Text(
            'Koraci pripreme nisu uneti.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final (n, step) in recipe.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${n + 1}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
        if (origin != null) ...[
          const SizedBox(height: 16),
          Text(origin, style: theme.textTheme.bodySmall),
        ],
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
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Izmeni oznake'),
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
  const ReadableScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
