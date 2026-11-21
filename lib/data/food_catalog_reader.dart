import 'package:drift/drift.dart';

import '../domain/food_matcher.dart';
import 'database.dart';

/// Matcher kataloga (018, D1-007) nad lokalnim kešom: deljeni redovi i redovi
/// traženog domaćinstva. Prazan keš (npr. stariji server bez kataloga) daje
/// Unresolved za svako ime.
class FoodCatalogReader {
  FoodCatalogReader(this._db);

  final AppDatabase _db;

  Future<FoodMatcher> matcherFor(FoodLookupScope scope) async {
    final hid = scope.householdId;
    final foodRows = await (_db.select(
      _db.foods,
    )..where((t) => t.householdId.isNull() | t.householdId.equals(hid))).get();
    final aliasRows = await (_db.select(
      _db.foodAliases,
    )..where((t) => t.householdId.isNull() | t.householdId.equals(hid))).get();

    // Osnovna jedinica koju ova verzija ne zna: namirnica se preskače, a sa
    // njom i aliasi (sirova vrednost ostaje u kešu).
    final foods = <String, CatalogFood>{};
    for (final r in foodRows) {
      final unit = FoodBaseUnit.values.asNameMap()[r.baseUnit];
      if (unit == null) continue;
      foods[r.id] = CatalogFood(
        FoodIdentity(
          id: r.id,
          slug: r.slug,
          name: r.name,
          category: r.category,
          baseUnit: unit,
        ),
        householdId: r.householdId,
        withdrawn: r.withdrawnAt != null,
      );
    }
    return AliasFoodMatcher([
      for (final a in aliasRows)
        if (foods[a.foodId] case final f?)
          AliasEntry(
            food: f.food,
            aliasNormalized: a.aliasNormalized,
            householdId: a.householdId,
            withdrawn: a.withdrawnAt != null,
          ),
    ], foods: foods.values.toList());
  }
}
