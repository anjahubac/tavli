import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/recipe_format.dart';
import 'recipe_providers.dart';

/// Poništava poslednju izmenu recepta i javlja ishod.
Future<void> undoLastChange(
  BuildContext context,
  WidgetRef ref,
  String recipeId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final undone = await ref.read(recipeRepositoryProvider).undoLast(recipeId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          undone ? 'Izmena je poništena.' : 'Nema izmena za poništavanje.',
        ),
      ),
    );
}

/// Lista prethodnih verzija; "Vrati" vraća recept kakav je bio pre te izmene.
Future<void> showVersionsSheet(BuildContext context, String recipeId) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final versions = ref.watch(recipeVersionsProvider(recipeId));
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Prethodne verzije',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Svaka stavka vraća recept kakav je bio pre te izmene.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Flexible(
                  child: versions.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Verzije nisu učitane.'),
                    ),
                    data: (list) => list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Još nema prethodnih verzija.'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final v = list[i];
                              final when = formatDateTime(
                                v.createdAt.toLocal(),
                              );
                              return ListTile(
                                title: Text(
                                  v.instruction == null
                                      ? v.kind.label
                                      : '${v.kind.label}: „${v.instruction}“',
                                ),
                                subtitle: Text(when),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final repo = ref.read(
                                      recipeRepositoryProvider,
                                    );
                                    Navigator.of(sheetContext).pop();
                                    await repo.restore(v.id);
                                    messenger
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Vraćena je verzija od $when.',
                                          ),
                                        ),
                                      );
                                  },
                                  child: const Text('Vrati'),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
