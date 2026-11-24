import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/auth_controller.dart';
import '../../data/cookbook_repository.dart';
import '../../domain/cookbook.dart';
import '../../providers.dart';
import 'book_picker.dart';

final bookPickerProvider = Provider<BookPicker>(
  (ref) => const FileSelectorBookPicker(),
);

/// Knjige domaćinstva; null dok nema prijave ili podešenog servera.
final cookbookRepositoryProvider = Provider<CookbookRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final scope = ref.watch(accountScopeProvider);
  if (client == null || scope == null) return null;
  return SupabaseCookbookRepository(client, scope.householdId);
});

final cookbooksProvider = FutureProvider.autoDispose<List<Cookbook>>((ref) {
  final repo = ref.watch(cookbookRepositoryProvider);
  return repo == null ? Future.value(const []) : repo.list();
});
