import 'recipe.dart';
import 'shopping_sync.dart' show ingredientKey;

/// Namirnica iz ostave za poređenje: naziv, id iz kataloga kad je poznat i
/// raspoloživa količina (`null` znači da je tu, a količina nije poznata).
typedef PantryFood = ({String name, String? foodId, double? quantity});

/// So, biber, ulje i voda se ne računaju kao sastojak koji fali
/// (TRELLO-103), ni kao sastojak koji imaš. Poređenje je po rečima naziva,
/// pa važi i za „morska so“, „crni biber“ ili „maslinovo ulje“.
bool isPantryStaple(String name) =>
    ingredientKey(name).split(' ').any(_stapleWords.contains);

const _stapleWords = {
  'so',
  'soli',
  'biber',
  'bibera',
  'ulje',
  'ulja',
  'voda',
  'vode',
};

/// Sačuvan recept i koliko njegovih sastojaka već imaš u ostavi.
class PantrySuggestion {
  const PantrySuggestion({
    required this.recipe,
    required this.have,
    required this.missing,
  });

  final Recipe recipe;

  /// Broj sastojaka (bez osnovnih) koje imaš.
  final int have;

  /// Nazivi sastojaka koji fale, redom iz recepta, bez ponavljanja.
  final List<String> missing;

  bool get hasEverything => missing.isEmpty;
}

/// „Šta da skuvam od onoga što imam“ (TRELLO-103): sačuvani recepti sa bar
/// jednim sastojkom iz ostave, prvo oni kojima fali najmanje, pa oni sa
/// više poklopljenih, pa po nazivu.
///
/// Sastojak se poklapa sa namirnicom preko id-ja iz kataloga, a kad veze
/// nema, po nazivu ([ingredientKey]). Računa se samo da li namirnicu imaš,
/// ne i koliko; namirnica sa količinom 0 (potrošena) se ne računa. Radi nad
/// lokalnim podacima, bez mreže.
List<PantrySuggestion> suggestFromPantry(
  Iterable<Recipe> recipes,
  Iterable<PantryFood> pantry,
) {
  final ids = <String>{};
  final names = <String>{};
  for (final food in pantry) {
    if (food.quantity case final q? when q <= 0) continue;
    if (food.foodId case final id?) ids.add(id);
    names.add(ingredientKey(food.name));
  }
  if (ids.isEmpty && names.isEmpty) return const [];

  final result = <PantrySuggestion>[];
  for (final recipe in recipes) {
    final seen = <String>{};
    final missing = <String>[];
    var have = 0;
    for (final ingredient in recipe.ingredients) {
      final key = ingredientKey(ingredient.name);
      if (key.isEmpty || isPantryStaple(ingredient.name)) continue;
      final foodId = ingredient.link?.foodId;
      // Isti sastojak dva puta u receptu (npr. za fil i za sos) broji se
      // jednom.
      if (!seen.add(foodId ?? key)) continue;
      if ((foodId != null && ids.contains(foodId)) || names.contains(key)) {
        have++;
      } else {
        missing.add(ingredient.name.trim());
      }
    }
    if (have > 0) {
      result.add(
        PantrySuggestion(recipe: recipe, have: have, missing: missing),
      );
    }
  }
  result.sort((a, b) {
    final byMissing = a.missing.length.compareTo(b.missing.length);
    if (byMissing != 0) return byMissing;
    final byHave = b.have.compareTo(a.have);
    if (byHave != 0) return byHave;
    return a.recipe.title.toLowerCase().compareTo(b.recipe.title.toLowerCase());
  });
  return result;
}
