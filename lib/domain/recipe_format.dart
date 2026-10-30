import 'recipe.dart';

/// Količina sa decimalnim zarezom, najviše dve decimale, bez suvišnih nula.
String formatQuantity(double q) {
  final fixed = q.toStringAsFixed(2);
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.replaceAll('.', ',');
}

/// "0,5 kg mleveno meso", "biber (po ukusu)".
String ingredientLine(Ingredient i) {
  final parts = [
    if (i.quantity != null) formatQuantity(i.quantity!),
    if (i.unit != null) i.unit!,
    i.name,
  ];
  final note = i.note == null ? '' : ' (${i.note})';
  return '${parts.join(' ')}$note';
}

/// Sastojci po kategorijama, redom kojim se ide kroz prodavnicu.
/// Nepoznata kategorija ide u "ostalo".
List<(String, List<Ingredient>)> groupByCategory(List<Ingredient> items) {
  final byCategory = <String, List<Ingredient>>{};
  for (final i in items) {
    final c = ingredientCategories.contains(i.category) ? i.category : 'ostalo';
    byCategory.putIfAbsent(c, () => []).add(i);
  }
  return [
    for (final c in ingredientCategories)
      if (byCategory[c] case final list?) (c, list),
  ];
}

/// Mala slova, bez kvačica (č/ć→c, š→s, ž→z, đ→dj), za pretragu.
String normalizeForSearch(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[čć]'), 'c')
    .replaceAll('š', 's')
    .replaceAll('ž', 'z')
    .replaceAll('đ', 'dj')
    .trim();

List<Recipe> filterRecipes(List<Recipe> recipes, String query) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return recipes;
  return [
    for (final r in recipes)
      if (normalizeForSearch(r.title).contains(q)) r,
  ];
}

/// "07.03.2026. 09:05"
String formatDateTime(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year}. ${_two(t.hour)}:${_two(t.minute)}';

String _two(int n) => n.toString().padLeft(2, '0');
