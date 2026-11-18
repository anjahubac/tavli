import 'shopping_sync.dart';

/// Osnovna jedinica namirnice (ugovor o identitetu sastojka, verzija 1).
enum FoodBaseUnit { piece, gram, milliliter }

/// Namirnica iz kataloga. `id` je nepromenljiv UUID i ne izvodi se iz imena.
final class FoodIdentity {
  const FoodIdentity({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.baseUnit,
  });

  final String id;
  final String slug;
  final String name;
  final String category;
  final FoodBaseUnit baseUnit;

  @override
  bool operator ==(Object other) => other is FoodIdentity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Domaćinstvo u čijem opsegu se traži. Ugovor imenuje tip, ali ga ne
/// definiše; za sada nosi samo identifikator domaćinstva.
final class FoodLookupScope {
  const FoodLookupScope({required this.householdId});

  final String householdId;
}

sealed class FoodMatchResult {
  const FoodMatchResult();
}

/// Postoji dokaz da ulaz označava vraćenu namirnicu.
final class Matched extends FoodMatchResult {
  const Matched(this.food);

  final FoodIdentity food;
}

/// Nema pouzdanog poklapanja; originalni tekst ostaje upotrebljiv.
final class Unresolved extends FoodMatchResult {
  const Unresolved();
}

/// Predlog za postojeću vidljivu namirnicu (v1 ga nikad ne vraća).
final class Proposed extends FoodMatchResult {
  const Proposed(this.candidate);

  final FoodIdentity candidate;
}

abstract interface class FoodMatcher {
  Future<FoodMatchResult> findByName({
    required String originalText,
    required FoodLookupScope scope,
  });
}

/// Jedan red aliasa. `householdId == null` znači deljeni alias.
final class AliasEntry {
  const AliasEntry({
    required this.food,
    required this.aliasNormalized,
    this.householdId,
  });

  final FoodIdentity food;
  final String aliasNormalized;
  final String? householdId;
}

/// Matcher v1: samo tačan alias (ili kanonsko ime) preko `ingredientKey`.
final class AliasFoodMatcher implements FoodMatcher {
  AliasFoodMatcher(List<AliasEntry> entries)
    : _entries = [
        ...entries,
        for (final e in entries)
          AliasEntry(
            food: e.food,
            aliasNormalized: ingredientKey(e.food.name),
            householdId: e.householdId,
          ),
      ];

  final List<AliasEntry> _entries;

  @override
  Future<FoodMatchResult> findByName({
    required String originalText,
    required FoodLookupScope scope,
  }) async {
    final key = ingredientKey(originalText);
    if (key.isEmpty) return const Unresolved();
    final own = _foodsFor(key, scope.householdId);
    // Potvrda domaćinstva ima prednost nad deljenim aliasom.
    final foods = own.isNotEmpty ? own : _foodsFor(key, null);
    return foods.length == 1
        ? Matched(foods.values.single)
        : const Unresolved();
  }

  /// Namirnice čiji alias odgovara ključu; `householdId == null` = deljeni.
  Map<String, FoodIdentity> _foodsFor(String key, String? householdId) => {
    for (final e in _entries)
      if (e.householdId == householdId && e.aliasNormalized == key)
        e.food.id: e.food,
  };
}
