import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pantry_repository.dart';
import '../../domain/food_matcher.dart';
import '../../providers.dart' show syncEngineProvider;
import '../shopping/shopping_providers.dart' show pantryRepositoryProvider;

/// Namirnice u ostavi domaćinstva, uživo, po nazivu.
final pantryEntriesProvider = StreamProvider.autoDispose<List<PantryEntry>>(
  (ref) => ref.watch(pantryRepositoryProvider).watchEntries(),
);

/// Upit „šta imam“ za nabavku i predloge recepata: šta je u ostavi, sa
/// raspoloživom količinom i id-jem iz kataloga. Osvežava se sa ostavom;
/// bez preuzetog kataloga sve namirnice ostaju samo po nazivu.
final pantryStockProvider = FutureProvider.autoDispose<List<PantryStock>>((
  ref,
) async {
  ref.watch(pantryEntriesProvider);
  final engine = ref.watch(syncEngineProvider);
  final matcher = engine == null
      ? AliasFoodMatcher(const [])
      : await engine.catalogMatcher();
  return ref.read(pantryRepositoryProvider).whatIHave(matcher);
});
