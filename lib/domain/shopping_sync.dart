import 'recipe.dart';

/// Ključ po kome se sastojak recepta poredi sa stavkom u kupovini.
String ingredientKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Šta treba promeniti u kupovini za jedan recept.
class ShoppingSyncPlan {
  const ShoppingSyncPlan({required this.toAdd, required this.toRemove});

  /// Nedostajući sastojci kojih iz ovog recepta još nema u kupovini.
  final List<Ingredient> toAdd;

  /// Ključevi stavki ovog recepta koje korisnik ipak ima (a nisu kupljene).
  final List<String> toRemove;
}

/// Štiklirano = imam (ne ide u kupovinu). "Dodaj u kupovinu" dodaje samo
/// razliku: neštiklirane kojih još nema u kupovini iz ovog recepta, pa
/// ponovni klik ništa ne duplira. Stavka koju korisnik naknadno označi kao
/// "imam", a nije kupljena, izlazi iz kupovine.
ShoppingSyncPlan planRecipeShopping({
  required List<Ingredient> missing,
  required List<Ingredient> have,
  required Set<String> inList,
  Set<String> bought = const {},
}) {
  final seen = <String>{};
  return ShoppingSyncPlan(
    toAdd: [
      for (final i in missing)
        if (!inList.contains(ingredientKey(i.name)) &&
            seen.add(ingredientKey(i.name)))
          i,
    ],
    toRemove: [
      for (final i in have)
        if (inList.contains(ingredientKey(i.name)) &&
            !bought.contains(ingredientKey(i.name)))
          ingredientKey(i.name),
    ],
  );
}
