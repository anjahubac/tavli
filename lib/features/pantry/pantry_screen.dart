import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/empty_fridge.dart';
import '../../app/home_shell.dart' show wideLayoutWidth;
import '../../app/placeholder_screen.dart' show EmptyStateBody;
import '../../app/tab_app_bar.dart';
import '../../data/pantry_repository.dart';
import '../recipes/cook_from_pantry_screen.dart' show cookFromPantryPath;
import '../shopping/shopping_list_view.dart' show amountLabel;
import '../shopping/shopping_providers.dart' show pantryRepositoryProvider;
import 'add_pantry_item_sheet.dart';
import 'pantry_providers.dart';

/// Najveća širina pretrage u zaglavlju na računaru (platno: 300); u užem
/// prozoru polje se skuplja.
const _searchMaxWidth = 300.0;

/// Prazan prostor ispod liste na telefonu, da plutajuće dugme ne pokrije
/// poslednju namirnicu.
const _floatingButtonClearance = 88.0;

/// „1 namirnica“, „3 namirnice“, „7 namirnica“, „21 namirnica“.
String pantryCountLabel(int n) {
  final ones = n % 10;
  final tens = n % 100;
  final few = ones >= 2 && ones <= 4 && (tens < 12 || tens > 14);
  return '$n ${few ? 'namirnice' : 'namirnica'}';
}

/// Tab „Ostava“, po platnu. Telefon: pretraga, broj namirnica, lista u
/// jednoj kartici (prevlačenje ulevo otkriva „Ukloni“) i plutajuće „Dodaj
/// namirnicu“. Računar: zaglavlje sa pretragom i „Dodaj namirnicu“, broj
/// namirnica i tabela Namirnica · Količina sa kantom kad je miš iznad reda.
/// Prisustvo u ostavi znači „imam“, pa redovi nemaju oznaku stanja; red bez
/// količine prikazuje samo naziv.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _search = TextEditingController();

  // Pretraga prelazi iz liste u zaglavlje kad se prozor raširi; ključ čuva
  // isto polje, pa tekst i fokus ostaju.
  final _searchKey = GlobalKey();

  /// Uklonjene namirnice dok traje poruka sa „Vrati“: skrivene su, a iz
  /// ostave se brišu tek kad se poruka zatvori bez „Vrati“ (obrisan zapis
  /// ne može da se vrati na server pod istim id-jem).
  final _pendingRemoval = <String>{};

  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _remove(PantryEntry entry) {
    final repo = ref.read(pantryRepositoryProvider);
    setState(() => _pendingRemoval.add(entry.id));
    final message = showTavliMessage(
      context,
      'Uklonjeno: ${entry.name}',
      actionLabel: 'Vrati',
      onAction: () {
        if (mounted) setState(() => _pendingRemoval.remove(entry.id));
      },
    );
    unawaited(
      message.closed.then((reason) async {
        if (reason == SnackBarClosedReason.action) return;
        await repo.removeEntry(entry);
        if (mounted) setState(() => _pendingRemoval.remove(entry.id));
      }),
    );
  }

  void _add() => unawaited(showAddPantryItemSheet(context, ref));

  Widget _searchField() => TavliSearchField(
    key: _searchKey,
    hint: 'Pretraži ostavu',
    controller: _search,
    onChanged: (q) => setState(() => _query = q),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(pantryEntriesProvider);
    final entries = [
      for (final e in all.value ?? const <PantryEntry>[])
        if (!_pendingRemoval.contains(e.id)) e,
    ];
    final hasItems = entries.isNotEmpty;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? entries
        : [
            for (final e in entries)
              if (e.name.toLowerCase().contains(q)) e,
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = MediaQuery.sizeOf(context).width >= wideLayoutWidth;
        final Widget content = switch (all) {
          AsyncError() => const Center(
            child: TavliEmptyState(
              icon: Icons.error_outline,
              title: 'Ostava nije učitana.',
            ),
          ),
          AsyncData() when !hasItems => const EmptyStateBody(
            art: EmptyFridge(),
            title: 'Još nema unetih namirnica',
            body: 'Ovde ćeš pratiti namirnice koje imaš kod kuće.',
          ),
          AsyncData() => _PantryContent(
            wide: wide,
            entries: shown,
            total: entries.length,
            query: _query.trim(),
            onRemove: _remove,
            onEdit: (e) =>
                unawaited(showEditPantryAmountSheet(context, ref, e)),
          ),
          _ => const TavliLoading(),
        };

        return Scaffold(
          appBar: const TabAppBar(),
          floatingActionButton: wide || !hasItems
              ? null
              : TavliFloatingButton(
                  icon: Icons.add,
                  label: 'Dodaj namirnicu',
                  onPressed: _add,
                ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TavliSpacing.large,
                    TavliSpacing.large,
                    TavliSpacing.large,
                    TavliSpacing.medium,
                  ),
                  child: TavliPageHeader(
                    title: 'Ostava',
                    actions: [
                      if (hasItems)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _searchMaxWidth,
                          ),
                          child: _searchField(),
                        ),
                      // TRELLO-103: recepti od onoga što je u ostavi.
                      if (hasItems)
                        TavliButton.secondary(
                          label: 'Šta da skuvam?',
                          glyph: TavliIcons.cook,
                          onPressed: () => context.push(cookFromPantryPath),
                        ),
                      TavliButton.primary(
                        label: 'Dodaj namirnicu',
                        icon: Icons.add,
                        onPressed: _add,
                      ),
                    ],
                  ),
                )
              else if (hasItems)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TavliSpacing.large,
                    TavliSpacing.small,
                    TavliSpacing.large,
                    TavliSpacing.medium,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _searchField()),
                      const SizedBox(width: TavliSpacing.small),
                      // TRELLO-103: recepti od onoga što je u ostavi.
                      TavliIconButton(
                        glyph: TavliIcons.cook,
                        semanticLabel: 'Šta da skuvam?',
                        onPressed: () => context.push(cookFromPantryPath),
                      ),
                    ],
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

/// Broj namirnica i lista (telefon) ili tabela (računar).
class _PantryContent extends StatelessWidget {
  const _PantryContent({
    required this.wide,
    required this.entries,
    required this.total,
    required this.query,
    required this.onRemove,
    required this.onEdit,
  });

  final bool wide;
  final List<PantryEntry> entries;
  final int total;
  final String query;
  final ValueChanged<PantryEntry> onRemove;
  final ValueChanged<PantryEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Center(
        child: TavliEmptyState(
          icon: Icons.search_off,
          title: 'Nema namirnica za „$query“.',
        ),
      );
    }
    final count = Text(
      pantryCountLabel(total),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final list = wide
        ? TavliDataTable(
            columns: const [
              TavliColumn('Namirnica', flex: 4),
              TavliColumn('Količina', alignEnd: true),
            ],
            rows: [
              for (final e in entries)
                TavliTableRow(
                  [e.name, amountLabel(e.quantity, e.unit) ?? ''],
                  onTap: () => onEdit(e),
                  onRemove: () => onRemove(e),
                  removeLabel: 'Ukloni iz ostave',
                ),
            ],
          )
        : TavliListGroup(
            children: [
              for (final e in entries)
                TavliListRow(
                  key: ValueKey(e.id),
                  title: e.name,
                  quantity: amountLabel(e.quantity, e.unit),
                  onTap: () => onEdit(e),
                  onRemove: () => onRemove(e),
                ),
            ],
          );
    return ListView(
      key: const PageStorageKey('pantry-list'),
      padding: EdgeInsets.fromLTRB(
        TavliSpacing.large,
        0,
        TavliSpacing.large,
        wide ? TavliSpacing.large : _floatingButtonClearance,
      ),
      children: [
        count,
        const SizedBox(height: TavliSpacing.medium),
        list,
      ],
    );
  }
}
