import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

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

/// Izabrane oznake u formi, pre čuvanja.
typedef LabelChoice = ({
  Set<MealSuitability> meals,
  DishWeight? weight,
  DishKind? dishKind,
});

LabelChoice labelChoiceOf(RecipeLabels labels) => (
  meals: labels.mealSet,
  weight: labels.weightValue,
  dishKind: labels.dishKindValue,
);

/// Ništa nije izabrano.
bool isEmptyChoice(LabelChoice c) =>
    c.meals.isEmpty && c.weight == null && c.dishKind == null;

bool sameChoice(LabelChoice a, LabelChoice b) =>
    a.weight == b.weight &&
    a.dishKind == b.dishKind &&
    a.meals.length == b.meals.length &&
    a.meals.containsAll(b.meals);

RecipeLabels labelsByUser(LabelChoice c) =>
    RecipeLabels.byUser(meals: c.meals, weight: c.weight, dishKind: c.dishKind);

/// Čipovi za obrok, težinu i vrstu jela; isti u listu „Oznake“ i u ručnoj
/// formi recepta.
class RecipeLabelsPicker extends StatelessWidget {
  const RecipeLabelsPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LabelChoice value;

  /// Dobija izmenu koju roditelj primenjuje na svoje trenutno stanje, pa se
  /// dva brza dodira pre novog crtanja ne poništavaju.
  final ValueChanged<LabelChoice Function(LabelChoice)> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(
        top: TavliSpacing.medium,
        bottom: TavliSpacing.small,
      ),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        title('Obrok'),
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            for (final m in MealSuitability.values)
              FilterChip(
                label: Text(m.label),
                selected: v.meals.contains(m),
                onSelected: (on) => onChanged(
                  (c) => (
                    meals: on ? {...c.meals, m} : ({...c.meals}..remove(m)),
                    weight: c.weight,
                    dishKind: c.dishKind,
                  ),
                ),
              ),
          ],
        ),
        title('Težina'),
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            for (final w in DishWeight.values)
              ChoiceChip(
                label: Text(w.label),
                selected: v.weight == w,
                onSelected: (on) => onChanged(
                  (c) => (
                    meals: c.meals,
                    weight: on ? w : null,
                    dishKind: c.dishKind,
                  ),
                ),
              ),
          ],
        ),
        title('Vrsta jela'),
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            for (final k in DishKind.values)
              ChoiceChip(
                label: Text(k.label),
                selected: v.dishKind == k,
                onSelected: (on) => onChanged(
                  (c) => (
                    meals: c.meals,
                    weight: c.weight,
                    dishKind: on ? k : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LabelsSheet extends StatefulWidget {
  const _LabelsSheet(this.current);

  final RecipeLabels current;

  @override
  State<_LabelsSheet> createState() => _LabelsSheetState();
}

class _LabelsSheetState extends State<_LabelsSheet> {
  late LabelChoice _choice = labelChoiceOf(widget.current);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TavliSpacing.large,
          0,
          TavliSpacing.large,
          TavliSpacing.large,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Oznake', style: theme.textTheme.titleLarge),
            RecipeLabelsPicker(
              value: _choice,
              onChanged: (update) => setState(() => _choice = update(_choice)),
            ),
            const SizedBox(height: TavliSpacing.large),
            TavliButtonRow(
              expand: true,
              children: [
                TavliButton.secondary(
                  label: 'Otkaži',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TavliButton.primary(
                  label: 'Sačuvaj',
                  onPressed: () =>
                      Navigator.of(context).pop(labelsByUser(_choice)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
