import 'recipe.dart';
import 'recipe_format.dart';

/// Sastojci koje korak pominje, redom iz recepta (režim kuvanja,
/// „U ovom koraku“). Recept ne vezuje sastojke za korake, pa se traži
/// naziv sastojka u tekstu koraka: ceo naziv, ili jedna njegova reč od
/// bar četiri slova po korenu (bez poslednjeg slova), da „luk“ u
/// „crni luk“ ne nađe „lukovicu“, a „krompir“ nađe „krompire“.
/// Poređenje je bez kvačica i velikih slova.
List<Ingredient> ingredientsInStep(String step, List<Ingredient> ingredients) {
  final words = _words(step);
  final text = ' ${words.join(' ')} ';
  return [
    for (final i in ingredients)
      if (_mentions(text, words, i.name)) i,
  ];
}

bool _mentions(String text, List<String> words, String name) {
  final parts = _words(name);
  if (parts.isEmpty) return false;
  if (text.contains(' ${parts.join(' ')} ')) return true;
  for (final p in parts) {
    if (p.length < 4) continue;
    final root = p.substring(0, p.length - 1);
    if (words.any((w) => w.startsWith(root))) return true;
  }
  return false;
}

List<String> _words(String s) =>
    normalizeForSearch(s)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
