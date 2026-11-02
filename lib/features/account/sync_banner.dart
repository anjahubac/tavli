import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../sync/sync_engine.dart';

/// Kad prebačeni stari podaci stignu na server (prikazuje `TavliApp`).
const dataMovedText = 'Tvoji recepti i liste su sačuvani u nalogu.';

/// Traka dok traje prebacivanje starih podataka ili prvo preuzimanje.
/// Aplikacija je za to vreme upotrebljiva (slike mogu da stignu kasnije).
/// Kad prebačeni stari podaci stignu na server, kratka poruka.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(movedSavedProvider, (_, next) {
      if (next.value case final n? when n > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(dataMovedText)));
      }
    });
    final phase = ref.watch(syncPhaseProvider).value;
    if (phase == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = switch (phase) {
      SyncPhase.moving => 'Čuvam tvoje podatke…',
      SyncPhase.downloading => 'Preuzimam tvoje podatke…',
    };
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_sync_outlined,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
