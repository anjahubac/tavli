/// Bezbednost recepata za plan domaćinstva (spec 019 FR-104/105, ugovor 008
/// "Allergen protection", TRELLO-43).
///
/// Server čita alergene svih članova i kaže samo da li ograničenja postoje i
/// koji od datih recepata smeju u plan. Aplikacija nikad ne dobija alergene,
/// pa ni AI.
library;

/// Odgovor servera za jedan skup recepata.
final class PlanSafety {
  const PlanSafety.unrestricted()
    : restricted = false,
      safeRecipeIds = const {};

  const PlanSafety.restricted(this.safeRecipeIds) : restricted = true;

  /// Bar jedan član domaćinstva ima alergiju: plan bira samo iz
  /// [safeRecipeIds] i ne izmišlja nova jela.
  final bool restricted;

  /// Recepti čiji su svi sastojci poznati i bez alergena domaćinstva.
  final Set<String> safeRecipeIds;

  /// Da li recept sme u plan.
  bool allows(String recipeId) =>
      !restricted || safeRecipeIds.contains(recipeId);

  /// Čita odgovor servera; pogrešan oblik baca [FormatException].
  factory PlanSafety.fromJson(Map<String, Object?> json) {
    final restricted = json['restricted'];
    if (restricted == false) return const PlanSafety.unrestricted();
    final ids = json['safeRecipeIds'];
    if (restricted != true ||
        ids is! List<Object?> ||
        !ids.every((id) => id is String)) {
      throw const FormatException('Neispravna provera recepata');
    }
    return PlanSafety.restricted(ids.cast<String>().toSet());
  }
}

/// Provera recepata pre svakog rasporeda i pre nego što se nacrt vrati.
abstract interface class PlanSafetySource {
  Future<PlanSafety> check(Set<String> recipeIds);
}

/// Provera trenutno nije moguća (mreža, server). Plan se ne pravi bez nje:
/// ne zna se da li neko ima alergiju.
class PlanSafetyUnavailable implements Exception {
  const PlanSafetyUnavailable();
}
