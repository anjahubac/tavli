import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';
import '../../data/food_catalog_reader.dart';
import '../../data/pantry_repository.dart' show PantryEntry;
import '../../domain/food_matcher.dart';
import '../../domain/recipe_format.dart' show formatQuantity;
import '../../providers.dart';
import '../../sync/catalog_status.dart';
import '../shopping/shopping_providers.dart' show pantryRepositoryProvider;
import 'pantry_amount_form.dart';
import 'pantry_providers.dart';

String _suggestedUnit(FoodBaseUnit? base) => switch (base) {
  FoodBaseUnit.gram => 'g',
  FoodBaseUnit.milliliter => 'ml',
  _ => 'kom',
};

/// Katalog namirnica koji odgovara upitu, iz lokalnog keša (radi i bez mreže).
final _catalogSearchProvider = FutureProvider.autoDispose
    .family<List<FoodIdentity>, String>((ref, query) async {
      final scope = ref.watch(accountScopeProvider);
      if (scope == null || query.trim().isEmpty) return const [];
      final db = ref.watch(databaseProvider);
      final account = await db.select(db.accounts).getSingleOrNull();
      final status =
          CatalogStatus.values.asNameMap()[account?.catalogStatus] ??
          CatalogStatus.notOnServer;
      return FoodCatalogReader(db).search(
        FoodLookupScope(householdId: scope.householdId),
        query,
        status: status,
      );
    });

/// „Dodaj namirnicu“, po platnu: pretraga kataloga, pa količina (nije
/// obavezna) i jedinica. Namirnica kojoj nema u katalogu dodaje se kao nova.
Future<void> showAddPantryItemSheet(BuildContext context, WidgetRef ref) =>
    showTavliSheet<void>(
      context,
      title: 'Dodaj namirnicu',
      builder: (_) => const AddPantryItemSheet(),
    );

class AddPantryItemSheet extends ConsumerStatefulWidget {
  const AddPantryItemSheet({super.key});

  @override
  ConsumerState<AddPantryItemSheet> createState() => _AddPantryItemSheetState();
}

class _AddPantryItemSheetState extends ConsumerState<AddPantryItemSheet> {
  final _search = TextEditingController();

  String _query = '';

  /// Izabrana namirnica (korak „količina“); `null` je korak „pretraga“.
  String? _name;
  String _category = 'ostalo';
  String _unit = 'kom';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(String name, {String? category, FoodBaseUnit? base}) =>
      setState(() {
        _name = name;
        _category = category ?? 'ostalo';
        _unit = _suggestedUnit(base);
      });

  Future<void> _save(double? quantity, String? unit) async {
    final name = _name;
    if (name == null) return;
    final navigator = Navigator.of(context);
    await ref
        .read(pantryRepositoryProvider)
        .add(name, quantity: quantity, unit: unit, category: _category);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) =>
      _name == null ? _searchStep(context) : _quantityStep(context);

  Widget _searchStep(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim();
    final found = ref.watch(_catalogSearchProvider(query)).value ?? const [];
    final inPantry = {
      for (final e
          in ref.watch(pantryEntriesProvider).value ?? const <PantryEntry>[])
        e.name.toLowerCase(),
    };
    final exact = found.any((f) => f.name.toLowerCase() == query.toLowerCase());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        TavliSearchField(
          hint: 'Potraži namirnicu',
          controller: _search,
          autofocus: true,
          onChanged: (q) => setState(() => _query = q),
          onSubmitted: (_) {
            if (query.isEmpty) return;
            if (found.isNotEmpty) {
              final f = found.first;
              _pick(f.name, category: f.category, base: f.baseUnit);
            } else {
              _pick(query);
            }
          },
        ),
        if (query.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              child: TavliListGroup(
                children: [
                  for (final f in found)
                    TavliListRow(
                      key: ValueKey(f.id),
                      title: f.name,
                      subtitle: inPantry.contains(f.name.toLowerCase())
                          ? 'Već u ostavi'
                          : null,
                      onTap: () =>
                          _pick(f.name, category: f.category, base: f.baseUnit),
                    ),
                  if (!exact)
                    TavliListRow(
                      title: 'Dodaj „$query“ kao novu namirnicu',
                      leading: const TavliIcon(TavliIcons.add),
                      onTap: () => _pick(query),
                    ),
                ],
              ),
            ),
          )
        else
          Text(
            'Namirnice iz kataloga; ono čega nema dodaješ kao novu.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _quantityStep(BuildContext context) {
    final theme = Theme.of(context);
    final name = _name!;
    final existing = ref
        .watch(pantryEntriesProvider)
        .value
        ?.where((e) => e.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TavliSpacing.medium,
      children: [
        Row(
          children: [
            TavliIconButton(
              glyph: TavliIcons.back,
              semanticLabel: 'Nazad na pretragu',
              onPressed: () => setState(() => _name = null),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  if (existing != null)
                    Text(
                      existing.quantity == null
                          ? 'Već u ostavi'
                          : 'Već u ostavi: ${formatQuantity(existing.quantity!)}'
                                '${existing.unit == null ? '' : ' ${existing.unit}'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        PantryAmountForm(
          // Nova namirnica kreće sa jedinicom koju katalog predlaže.
          key: ValueKey(name),
          initialUnit: _unit,
          saveLabel: 'Dodaj u ostavu',
          note:
              'Bez količine u ostavi stoji samo naziv. Ako namirnica već '
              'postoji, količina se dodaje na postojeću.',
          onSave: (q, u) => unawaited(_save(q, u)),
        ),
      ],
    );
  }
}

/// Izmena količine namirnice u ostavi (dodir na red): upisana količina je
/// novo stanje. Prazno polje znači da količina nije poznata.
Future<void> showEditPantryAmountSheet(
  BuildContext context,
  WidgetRef ref,
  PantryEntry entry,
) => showTavliSheet<void>(
  context,
  title: entry.name,
  builder: (sheetContext) => PantryAmountForm(
    initialQuantity: entry.quantity,
    initialUnit: entry.unit ?? 'kom',
    saveLabel: 'Sačuvaj',
    note: 'Upisana količina je novo stanje u ostavi.',
    onSave: (q, u) {
      unawaited(
        ref.read(pantryRepositoryProvider).setEntryQuantity(entry, q, unit: u),
      );
      Navigator.of(sheetContext).pop();
    },
  ),
);
