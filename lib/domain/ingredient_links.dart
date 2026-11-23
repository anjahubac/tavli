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
  final unlinkedKeys = <String, String>{};
  for (final i in from) {
    final key = ingredientKey(i.name);
    if (i.unlinkedKey == key) {
      unlinkedKeys[key] = key;
      continue;
    }
    final link = i.link;
    if (link == null || ingredientKey(i.name) != link.matchedKey) continue;
    final linkKey = link.matchedKey;
    byKey[linkKey] = byKey.containsKey(linkKey) && byKey[linkKey] != link
        ? null
        : link;
  }
  return [
    for (final i in to)
      _withLink(
        i,
        i.unlinkedKey == ingredientKey(i.name)
            ? null
            : byKey[ingredientKey(i.name)],
        unlinkedKey: i.unlinkedKey ?? unlinkedKeys[ingredientKey(i.name)],
      ),
  ];
}

/// Merges links from a server recipe into the locally edited recipe before an
/// upload. Intentional local unlinks win; otherwise confirmed links win over
/// matched links, with the local confirmed link taking precedence on ties.
/// Ingredient names and all other local fields remain untouched.
List<Ingredient> mergeIngredientLinks({
  required List<Ingredient> local,
  required List<Ingredient> server,
}) {
  final serverByKey = <String, IngredientLink?>{};
  for (final ingredient in server) {
    final key = ingredientKey(ingredient.name);
    final link = ingredient.link;
    if (link == null || key != link.matchedKey) continue;
    serverByKey[key] = serverByKey.containsKey(key) && serverByKey[key] != link
        ? null
        : link;
  }
  return [
    for (final ingredient in local)
      _withLink(
        ingredient,
        _mergedLink(ingredient, serverByKey[ingredientKey(ingredient.name)]),
      ),
  ];
}

IngredientLink? _mergedLink(Ingredient local, IngredientLink? serverLink) {
  final key = ingredientKey(local.name);
  if (local.unlinkedKey == key) return null;
  final localLink = local.link;
  final validLocal = localLink != null && localLink.matchedKey == key
      ? localLink
      : null;
  if (validLocal?.linkSource == LinkSource.confirmed) return validLocal;
  if (serverLink?.linkSource == LinkSource.confirmed) return serverLink;
  return validLocal ?? serverLink;
}

Ingredient _withLink(
  Ingredient i,
  IngredientLink? link, {
  String? unlinkedKey,
}) => i.link == link && i.unlinkedKey == (unlinkedKey ?? i.unlinkedKey)
    ? i
    : Ingredient(
        name: i.name,
        quantity: i.quantity,
        unit: i.unit,
        category: i.category,
        note: i.note,
        link: link,
        unlinkedKey: unlinkedKey ?? i.unlinkedKey,
      );
