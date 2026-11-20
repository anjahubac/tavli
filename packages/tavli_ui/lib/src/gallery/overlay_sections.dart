import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../controls/tavli_button.dart';
import '../controls/tavli_text_field.dart';
import '../overlays/tavli_action_menu.dart';
import '../overlays/tavli_dialog.dart';
import '../overlays/tavli_message.dart';
import '../overlays/tavli_sheet.dart';
import '../tokens.dart';
import 'gallery_section.dart';

const _menu = [
  TavliMenuAction('Izmeni', icon: Icons.edit_outlined, onSelected: _noop),
  TavliMenuAction(
    'Dodaj u plan',
    icon: Icons.event_outlined,
    onSelected: _noop,
  ),
  TavliMenuAction(
    'Ukloni',
    icon: Icons.delete_outline,
    isDestructive: true,
    onSelected: _noop,
  ),
];

void _noop() {}

/// Odeljci galerije za dijaloge, donji list, kratke poruke i meni akcija:
/// mirni prikaz izgleda i dugmad koja ih stvarno otvaraju.
class TavliOverlayGallerySections extends StatelessWidget {
  const TavliOverlayGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(
          title: 'Dijalozi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GalleryLabeled(
                'Android i Windows · radijus 24',
                TavliDialog<bool>(
                  title: 'Ukloniti recept?',
                  message: 'Sarma će biti uklonjena iz plana i kolekcije.',
                  actions: [
                    TavliDialogAction('Otkaži', false),
                    TavliDialogAction('Ukloni', true, isDestructive: true),
                  ],
                ),
              ),
              gap,
              GalleryLabeled(
                'iOS i macOS · sistemski izgled',
                Theme(
                  data: theme.copyWith(platform: TargetPlatform.iOS),
                  child: const TavliDialog<bool>(
                    title: 'Ukloniti recept?',
                    message: 'Sarma će biti uklonjena iz plana i kolekcije.',
                    actions: [
                      TavliDialogAction('Otkaži', false),
                      TavliDialogAction('Ukloni', true, isDestructive: true),
                    ],
                  ),
                ),
              ),
              gap,
              const _OpenDialogs(),
            ],
          ),
        ),
        GallerySection(
          title: 'Donji list i meni akcija',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GalleryLabeled(
                'Donji list · radijus 24 · meni na telefonu',
                TavliSheet(
                  title: 'Sarma',
                  child: TavliActionList(actions: _menu, onSelected: (_) {}),
                ),
              ),
              gap,
              const _OpenSheets(),
            ],
          ),
        ),
        GallerySection(
          title: 'Kratka poruka',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GalleryLabeled(
                'Nestaje posle 5 s · sa akcijom',
                TavliMessageBar(
                  message: 'Jaja su uklonjena iz ostave.',
                  actionLabel: 'Vrati',
                  onAction: () {},
                ),
              ),
              gap,
              const TavliMessageBar(message: 'Recept je sačuvan.'),
              gap,
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TavliButton.secondary(
                  label: 'Prikaži poruku',
                  onPressed: () => showTavliMessage(
                    context,
                    'Jaja su uklonjena iz ostave.',
                    actionLabel: 'Vrati',
                    onAction: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpenDialogs extends StatelessWidget {
  const _OpenDialogs();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      children: [
        TavliButton.secondary(
          label: 'Otvori potvrdu',
          onPressed: () => unawaited(
            showTavliConfirm(
              context,
              title: 'Ukloniti recept?',
              message: 'Sarma će biti uklonjena iz plana i kolekcije.',
              confirmLabel: 'Ukloni',
              destructive: true,
            ),
          ),
        ),
        TavliButton.secondary(
          label: 'Dijalog sa poljem',
          onPressed: () => unawaited(
            showTavliDialog<String>(
              context,
              title: 'Novi spisak',
              content: const TavliTextField(hint: 'npr. Za vikend'),
              actions: const [
                TavliDialogAction('Otkaži', ''),
                TavliDialogAction('Napravi', 'ok', isDefault: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenSheets extends StatelessWidget {
  const _OpenSheets();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TavliButton.secondary(
          label: 'Otvori donji list',
          onPressed: () => unawaited(
            showTavliSheet<void>(
              context,
              title: 'Dodaj namirnicu',
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TavliTextField(label: 'Naziv', hint: 'npr. Brašno'),
                  const SizedBox(height: TavliSpacing.medium),
                  TavliButton.primary(
                    label: 'Dodaj',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
        TavliButton.secondary(
          label: 'Meni akcija',
          onPressed: () => unawaited(
            showTavliActionMenu(context, title: 'Sarma', actions: _menu),
          ),
        ),
        const TavliMenuButton(title: 'Sarma', actions: _menu),
      ],
    );
  }
}
