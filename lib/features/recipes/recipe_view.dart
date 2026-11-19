import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../domain/recipe.dart';
import '../../domain/recipe_format.dart';
import 'recipe_photo.dart';

/// Visina slike recepta iznad sadržaja.
const _photoHeight = 220.0;

/// Najveća širina sadržaja recepta, da redovi ostanu čitljivi.
const _readableWidth = 720.0;

/// Sadržaj recepta: slika, porcije, sastojci po kategorijama, koraci.
/// Koristi se u detaljima, pregledu AI recepta i predlogu izmene.
class RecipeView extends StatelessWidget {
  const RecipeView(
    this.recipe, {
    super.key,
    this.photoBytes,
    this.showTitle = false,
  });

  final Recipe recipe;

  /// Slika koja još nije sačuvana (pregled recepta iz slike).
  final Uint8List? photoBytes;
  final bool showTitle;

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
            borderRadius: BorderRadius.circular(TavliRadius.field),
            child: Image.memory(
              bytes,
              height: _photoHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Slika recepta',
            ),
          )
        else if (path != null)
          RecipePhoto(path, height: _photoHeight),
        if (bytes != null || path != null)
          const SizedBox(height: TavliSpacing.large),
        if (showTitle) ...[
          Text(recipe.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: TavliSpacing.small),
        ],
        Wrap(
          spacing: TavliSpacing.large,
          runSpacing: TavliSpacing.small,
          children: [
            _Fact(Icons.people_outline, servingsLabel(recipe.servings)),
            if (recipe.prepMinutes != null)
              _Fact(Icons.timer_outlined, '${recipe.prepMinutes} min'),
          ],
        ),
        const SizedBox(height: TavliSpacing.medium),
        const TavliSectionHeader(
          'Sastojci',
          style: TavliSectionHeaderStyle.bold,
        ),
        for (final (category, items) in groupByCategory(
          recipe.ingredients,
        )) ...[
          TavliSectionHeader(category),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: TavliSpacing.small),
              child: Text('• ${ingredientLine(i)}'),
            ),
        ],
        const SizedBox(height: TavliSpacing.medium),
        const TavliSectionHeader(
          'Priprema',
          style: TavliSectionHeaderStyle.bold,
        ),
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
              padding: const EdgeInsets.only(bottom: TavliSpacing.small),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TavliSpacing.small,
                children: [
                  Text(
                    '${n + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
        if (origin != null) ...[
          const SizedBox(height: TavliSpacing.medium),
          Text(origin, style: theme.textTheme.bodySmall),
        ],
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
      padding: const EdgeInsets.all(TavliSpacing.large),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _readableWidth),
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
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TavliSpacing.small,
      children: [
        Icon(icon, color: muted),
        Text(text, style: TextStyle(color: muted)),
      ],
    );
  }
}
