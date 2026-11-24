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

/// "1 ocena", "2 ocene", "5 ocena" (11–14 su "ocena").
String ratingCountLabel(int n) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$n ocene';
  }
  return '$n ocena';
}

/// Prosek ocena sa jednom decimalom i zarezom: "4,3".
String ratingAverageLabel(double average) =>
    average.toStringAsFixed(1).replaceAll('.', ',');

/// Broj sa imenicom u pravom obliku: [one] za 1, 21, 31… (ali ne 11),
/// [few] za 2–4, 22–24… (ali ne 12–14), [many] za ostale.
/// `countLabel(3, 'stavka', 'stavke', 'stavki')` je "3 stavke".
String countLabel(int n, String one, String few, String many) {
  final lastTwo = n % 100;
  final last = n % 10;
  if (last == 1 && lastTwo != 11) return '$n $one';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$n $few';
  }
  return '$n $many';
}

/// "1 porcija", "2 porcije", "5 porcija" (11–14 su "porcija").
String servingsLabel(int n) => countLabel(n, 'porcija', 'porcije', 'porcija');

/// "07.03.2026. 09:05"
String formatDateTime(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year}. ${_two(t.hour)}:${_two(t.minute)}';

/// "09:05"
String formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String _two(int n) => n.toString().padLeft(2, '0');
