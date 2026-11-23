import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../account/auth_controller.dart';
import '../../../data/food_catalog_reader.dart';
import '../../../data/planning_sharing_repository.dart';
import '../../../domain/allergen_group.dart';
import '../../../domain/cuisine_preferences.dart';
import '../../../domain/dish_kind_preferences.dart';
import '../../../domain/food_preferences.dart';
import '../../../domain/recipe.dart';
import '../../../providers.dart';
import '../../../sync/sync_remote.dart';
import '../../recipes/recipe_providers.dart';

final allergenSelectionProvider =
    StreamProvider.autoDispose<Set<AllergenGroup>>(
      (ref) => ref.watch(allergenRepositoryProvider).watchSelection(),
    );

final dishPreferencesProvider = StreamProvider.autoDispose<DishKindPreferences>(
  (ref) => ref.watch(tasteProfileRepositoryProvider).watchDishPreferences(),
);

final cuisinePreferencesProvider =
    StreamProvider.autoDispose<CuisinePreferences>(
      (ref) =>
          ref.watch(tasteProfileRepositoryProvider).watchCuisinePreferences(),
    );

final foodPreferencesProvider = StreamProvider.autoDispose<FoodPreferences>(
  (ref) => ref.watch(tasteProfileRepositoryProvider).watchFoodPreferences(),
);

final favoriteRecipeIdsProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(favoriteRepositoryProvider).watchFavoriteRecipeIds(),
);

/// Omiljeni recepti aktivnog korisnika, redom kao u listi recepata.
final favoriteRecipesProvider = Provider.autoDispose<AsyncValue<List<Recipe>>>((
  ref,
) {
  final recipes = ref.watch(recipesProvider);
  final ids = ref.watch(favoriteRecipeIdsProvider);
  return switch ((recipes, ids)) {
    (AsyncData(value: final r), AsyncData(value: final f)) => AsyncData([
      for (final recipe in r)
        if (f.contains(recipe.id)) recipe,
    ]),
    (AsyncError(:final error, :final stackTrace), _) ||
    (
      _,
      AsyncError(:final error, :final stackTrace),
    ) => AsyncError(error, stackTrace),
    _ => const AsyncLoading(),
  };
});

/// Namirnice iz kataloga koje korisnik može da izabere.
final catalogFoodsProvider = StreamProvider.autoDispose<List<CatalogFoodEntry>>(
  (ref) {
    final scope = ref.watch(accountScopeProvider);
    if (scope == null) return Stream.value(const []);
    return CatalogFoodList(ref.watch(databaseProvider))
        .watchVisible(scope.householdId);
  },
);

/// Zašto promena deljenja nije uspela.
enum SharingFailure {
  /// Nema veze sa serverom (ili aplikacija nema server).
  offline,

  /// Drugi uređaj je u međuvremenu promenio podešavanje.
  changedElsewhere,

  /// Ostale greške servera.
  failed,
}

/// Saglasnost za deljenje ukusa i omiljenih u planu domaćinstva. Menja se
/// samo na mreži: važi vrednost koju server potvrdi (008, FR-111).
class PlanningSharingController extends AsyncNotifier<PlanningSharing> {
  @override
  Future<PlanningSharing> build() async {
    final repo = ref.watch(planningSharingRepositoryProvider);
    if (repo == null) throw const TransientSyncError('offline');
    return repo.getSharing();
  }

  /// Menja deljenje; vraća `null` kad server potvrdi promenu.
  Future<SharingFailure?> setPreferences(bool enabled) async {
    final repo = ref.read(planningSharingRepositoryProvider);
    final current = state.value;
    if (repo == null || current == null) return SharingFailure.offline;
    try {
      state = AsyncData(
        await repo.setPreferences(enabled, expectedRevision: current.revision),
      );
      return null;
    } on PlanningSharingConflict {
      ref.invalidateSelf();
      return SharingFailure.changedElsewhere;
    } on TransientSyncError {
      return SharingFailure.offline;
    } on Object {
      return SharingFailure.failed;
    }
  }
}

final planningSharingProvider =
    AsyncNotifierProvider.autoDispose<
      PlanningSharingController,
      PlanningSharing
    >(
      PlanningSharingController.new,
      // Bez ponavljanja u pozadini: ekran nudi „Pokušaj ponovo“.
      retry: (_, _) => null,
    );
