import 'package:drift/drift.dart';

import '../domain/food_matcher.dart';
import '../domain/food_nutrition.dart';
import '../sync/catalog_status.dart';
import 'database.dart';

/// Matcher kataloga (018, D1-007) nad lokalnim kešom: deljeni redovi i redovi
/// traženog domaćinstva. Prazan keš (npr. stariji server bez kataloga) daje
/// Unresolved za svako ime. Isto važi kad server javi [CatalogStatus.notOnServer]:
/// ranije preuzet keš se tada ne čita (može biti delimičan, npr. namirnice bez
/// aliasa).
class FoodCatalogReader {
  FoodCatalogReader(this._db);

  final AppDatabase _db;

  Future<FoodMatcher> matcherFor(
    FoodLookupScope scope, {
    required CatalogStatus status,
  }) async {
    if (status == CatalogStatus.notOnServer) return AliasFoodMatcher(const []);
    final hid = scope.householdId;
    final sharedOnly = status == CatalogStatus.accessDenied;
    final foodRows =
        await (_db.select(_db.foods)..where(
              (t) => sharedOnly
                  ? t.householdId.isNull()
                  : t.householdId.isNull() | t.householdId.equals(hid),
            ))
            .get();
    final aliasRows =
        await (_db.select(_db.foodAliases)..where(
              (t) => sharedOnly
                  ? t.householdId.isNull()
                  : t.householdId.isNull() | t.householdId.equals(hid),
            ))
            .get();

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
          nutrition: _nutrition(r),
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

  /// Namirnice kataloga čiji naziv ili alias sadrži [query] (bez obzira na
  /// velika slova), po nazivu; povučene se preskaču. Prazan upit daje
  /// prazan spisak. Katalog je lokalni keš, pa radi i bez mreže.
  Future<List<FoodIdentity>> search(
    FoodLookupScope scope,
    String query, {
    required CatalogStatus status,
    int limit = 8,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || status == CatalogStatus.notOnServer) return const [];
    final hid = scope.householdId;
    final sharedOnly = status == CatalogStatus.accessDenied;
    bool visible(String? household) =>
        household == null || (!sharedOnly && household == hid);

    final foods = [
      for (final r in await _db.select(_db.foods).get())
        if (r.withdrawnAt == null && visible(r.householdId)) r,
    ];
    final byId = {for (final f in foods) f.id: f};
    final matched = <String>{
      for (final f in foods)
        if (f.name.toLowerCase().contains(q)) f.id,
      for (final a in await _db.select(_db.foodAliases).get())
        if (a.withdrawnAt == null &&
            visible(a.householdId) &&
            byId.containsKey(a.foodId) &&
            a.alias.toLowerCase().contains(q))
          a.foodId,
    };
    final found = [
      for (final id in matched)
        if (FoodBaseUnit.values.asNameMap()[byId[id]!.baseUnit]
            case final unit?)
          FoodIdentity(
            id: id,
            slug: byId[id]!.slug,
            name: byId[id]!.name,
            category: byId[id]!.category,
            baseUnit: unit,
          ),
    ];
    // Prvo one koje počinju upitom, pa po nazivu.
    found.sort((a, b) {
      final ap = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      if (ap != bp) return ap - bp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return found.take(limit).toList();
  }

  FoodNutrition? _nutrition(FoodRow row) {
    final hasValues =
        row.kcalPer100g != null ||
        row.proteinGramsPer100g != null ||
        row.fatGramsPer100g != null ||
        row.carbsGramsPer100g != null;
    if (!hasValues) return null;
    final source = row.nutritionSource;
    final version = row.nutritionSourceVersion;
    final ref = row.nutritionSourceRef;
    if (source == null || version == null || ref == null) return null;
    final values = [
      row.kcalPer100g,
      row.proteinGramsPer100g,
      row.fatGramsPer100g,
      row.carbsGramsPer100g,
    ];
    if (values.any(
      (value) => value != null && (!value.isFinite || value < 0),
    )) {
      return null;
    }
    return FoodNutrition(
      kcalPer100g: row.kcalPer100g,
      proteinGramsPer100g: row.proteinGramsPer100g,
      fatGramsPer100g: row.fatGramsPer100g,
      carbsGramsPer100g: row.carbsGramsPer100g,
      source: source,
      sourceVersion: version,
      sourceRef: ref,
    );
  }
}

/// Namirnica iz kataloga za izbor u ukusima (Volim, Ne volim).
class CatalogFoodEntry {
  const CatalogFoodEntry({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category;
}

/// Namirnice koje korisnik može da izabere u ukusima: deljene i namirnice
/// njegovog domaćinstva iz lokalnog keša, bez povučenih, po nazivu.
class CatalogFoodList {
  CatalogFoodList(this._db);

  final AppDatabase _db;

  Stream<List<CatalogFoodEntry>> watchVisible(String householdId) =>
      (_db.select(_db.foods)
            ..where(
              (t) =>
                  t.withdrawnAt.isNull() &
                  (t.householdId.isNull() | t.householdId.equals(householdId)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map(
            (rows) => List.unmodifiable([
              for (final r in rows)
                CatalogFoodEntry(id: r.id, name: r.name, category: r.category),
            ]),
          );
}
