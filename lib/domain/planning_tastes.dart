import 'cuisine_preferences.dart';
import 'recipe.dart';
import 'recipe_labels.dart';

/// Ukusi članova za plan obroka (spec 019 FR-004, ugovor 008): spojeni
/// rezultat koji server vraća samo za članove koji su uključili deljenje za
/// planiranje. Bez članova, imena, omiljenih i alergena. Savet, ne zabrana:
/// „ne volim“ spušta jelo niže, a kad neko voli ono što drugi ne voli,
/// pobeđuje „ne volim“ (to već radi server).
final class PlanningTastes {
  PlanningTastes({
    Set<String> likedFoodIds = const {},
    Set<String> dislikedFoodIds = const {},
    Set<DishKind> likedDishKinds = const {},
    Set<DishKind> dislikedDishKinds = const {},
    Set<Cuisine> likedCuisines = const {},
    Set<Cuisine> dislikedCuisines = const {},
    Map<String, String> foodNames = const {},
  }) : likedFoodIds = Set.unmodifiable(likedFoodIds),
       dislikedFoodIds = Set.unmodifiable(dislikedFoodIds),
       likedDishKinds = Set.unmodifiable(likedDishKinds),
       dislikedDishKinds = Set.unmodifiable(dislikedDishKinds),
       likedCuisines = Set.unmodifiable(likedCuisines),
       dislikedCuisines = Set.unmodifiable(dislikedCuisines),
       foodNames = Map.unmodifiable(foodNames);

  /// Server vraća šest nizova; sve ostalo (npr. omiljeni) se ignoriše.
  /// Pogrešan tip baca [FormatException]; nepoznata vrsta jela ili kuhinja
  /// se preskače (novija verzija servera ne ruši stariju aplikaciju).
  factory PlanningTastes.fromJson(Map<String, Object?> json) {
    List<String> strings(String key) {
      final value = json[key];
      if (value is! List<Object?> || value.any((v) => v is! String)) {
        throw FormatException('Neispravni ukusi', key);
      }
      return value.cast<String>();
    }

    final cuisines = Cuisine.values.asNameMap();
    return PlanningTastes(
      likedFoodIds: strings('likedFoodIds').toSet(),
      dislikedFoodIds: strings('dislikedFoodIds').toSet(),
      likedDishKinds: strings('likedDishKinds')
          .map(DishKind.tryParse)
          .nonNulls
          .toSet(),
      dislikedDishKinds: strings('dislikedDishKinds')
          .map(DishKind.tryParse)
          .nonNulls
          .toSet(),
      likedCuisines: strings('likedCuisineCodes')
          .map((c) => cuisines[c])
          .nonNulls
          .toSet(),
      dislikedCuisines: strings('dislikedCuisineCodes')
          .map((c) => cuisines[c])
          .nonNulls
          .toSet(),
    );
  }

  /// Niko nije podelio ukuse (ili nema domaćinstva): običan plan.
  static final none = PlanningTastes();

  final Set<String> likedFoodIds;
  final Set<String> dislikedFoodIds;
  final Set<DishKind> likedDishKinds;
  final Set<DishKind> dislikedDishKinds;
  final Set<Cuisine> likedCuisines;
  final Set<Cuisine> dislikedCuisines;

  /// Nazivi namirnica iz lokalnog kataloga (id → naziv). Namirnica bez
  /// naziva i dalje utiče na redosled recepata, ali se ne navodi u upitu.
  final Map<String, String> foodNames;

  bool get isEmpty =>
      likedFoodIds.isEmpty &&
      dislikedFoodIds.isEmpty &&
      likedDishKinds.isEmpty &&
      dislikedDishKinds.isEmpty &&
      likedCuisines.isEmpty &&
      dislikedCuisines.isEmpty;

  PlanningTastes withFoodNames(Map<String, String> names) => PlanningTastes(
    likedFoodIds: likedFoodIds,
    dislikedFoodIds: dislikedFoodIds,
    likedDishKinds: likedDishKinds,
    dislikedDishKinds: dislikedDishKinds,
    likedCuisines: likedCuisines,
    dislikedCuisines: dislikedCuisines,
    foodNames: {
      for (final id in {...likedFoodIds, ...dislikedFoodIds}) id: ?names[id],
    },
  );

  /// Recept sadrži namirnicu koju neko ne voli (preko veze sa katalogom),
  /// ili je vrste jela koju neko ne voli. Takav recept ide na kraj liste
  /// koja se nudi AI-ju; ne izbacuje se.
  bool dislikes(Recipe recipe) =>
      dislikedDishKinds.contains(recipe.labels.dishKindValue) ||
      recipe.ingredients.any((i) => dislikedFoodIds.contains(i.link?.foodId));
}

/// Ukusi za sledeći zahtev ka AI-ju. Čitaju se pre svakog rasporeda, da
/// povučen pristanak važi odmah (ugovor 008: bez keša).
abstract interface class PlanningTastesSource {
  Future<PlanningTastes> current();
}

/// Server je odbio: promenjeno domaćinstvo ili istekla prijava. Plan se ne
/// pravi sa ukusima drugog domaćinstva; postojeći nacrt ostaje.
class PlanningTastesDenied implements Exception {
  const PlanningTastesDenied();
}

/// Ukusi trenutno nisu dostupni (mreža, server). Plan se pravi bez njih, a
/// osoba to vidi u poruci (`PlanDraft.withoutTastes`).
class PlanningTastesUnavailable implements Exception {
  const PlanningTastesUnavailable();
}
