import 'recipe.dart';
import 'shopping_sync.dart';

/// Prenosi veze sa katalogom (ugovor #30) sa starih sastojaka na nove, npr.
/// posle AI izmene recepta: AI ne sme da postavi vezu, pa se ona uzima iz
/// sačuvanih podataka. Sastojak dobija vezu samo ako je njegov
/// `ingredientKey(name)` jednak `matchedKey` važeće stare veze; ako dve stare
/// veze istog ključa pokazuju na različite namirnice, ne dobija nijednu.
List<Ingredient> carryIngredientLinks({
  required List<Ingredient> from,
  required List<Ingredient> to,
}) {
  final byKey = <String, IngredientLink?>{};
  for (final i in from) {
    final link = i.link;
    if (link == null || ingredientKey(i.name) != link.matchedKey) continue;
    final key = link.matchedKey;
    byKey[key] = byKey.containsKey(key) && byKey[key] != link ? null : link;
  }
  return [for (final i in to) _withLink(i, byKey[ingredientKey(i.name)])];
}

Ingredient _withLink(Ingredient i, IngredientLink? link) =>
    i.link != null || link == null
    ? i
    : Ingredient(
        name: i.name,
        quantity: i.quantity,
        unit: i.unit,
        category: i.category,
        note: i.note,
        link: link,
      );
