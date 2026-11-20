import 'package:material_ui/material_ui.dart';

import '../../domain/recipe_labels.dart';

/// Izmena oznaka recepta: obroci (više njih), težina i vrsta jela (po jedna).
/// Vraća nove oznake ili null kad korisnik odustane.
Future<RecipeLabels?> showRecipeLabelsSheet(
  BuildContext context,
  RecipeLabels current,
) => showModalBottomSheet<RecipeLabels>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _LabelsSheet(current),
);

class _LabelsSheet extends StatefulWidget {
  const _LabelsSheet(this.current);

  final RecipeLabels current;

  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  late final Set<MealSuitability> _meals = {...widget.current.mealSet};
  late DishWeight? _weight = widget.current.weightValue;
  late DishKind? _dishKind = widget.current.dishKindValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Oznake', style: theme.textTheme.titleLarge),
            title('Obrok'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MealSuitability.values)
                  FilterChip(
                    label: Text(m.label),
                    selected: _meals.contains(m),
                    onSelected: (on) =>
                        setState(() => on ? _meals.add(m) : _meals.remove(m)),
                  ),
              ],
            ),
            title('Težina'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in DishWeight.values)
                  ChoiceChip(
                    label: Text(w.label),
                    selected: _weight == w,
                    onSelected: (on) => setState(() => _weight = on ? w : null),
                  ),
              ],
            ),
            title('Vrsta jela'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in DishKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _dishKind == k,
                    onSelected: (on) =>
                        setState(() => _dishKind = on ? k : null),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Otkaži'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      RecipeLabels.byUser(
                        meals: _meals,
                        weight: _weight,
                        dishKind: _dishKind,
                      ),
                    ),
                    child: const Text('Sačuvaj'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
