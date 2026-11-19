import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../controls/tavli_icon_button.dart';
import '../platform.dart';
import '../tokens.dart';
import 'tavli_sheet.dart';

/// Stavka menija akcija.
class TavliMenuAction {
  const TavliMenuAction(
    this.label, {
    required this.onSelected,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;

  /// „Ukloni“, „Obriši“: crveno.
  final bool isDestructive;
}

/// Meni akcija:
/// - računar, sa [position] (desni klik ili dugme „Još opcija“): mali meni
///   na tom mestu;
/// - iOS i macOS bez mesta: sistemski akcioni list sa „Otkaži“;
/// - Android i Windows bez mesta: donji list sa listom akcija.
///
/// Izabrana akcija se poziva posle zatvaranja menija.
Future<void> showTavliActionMenu(
  BuildContext context, {
  required List<TavliMenuAction> actions,
  String? title,
  Offset? position,
  String cancelLabel = 'Otkaži',
}) async {
  final platform = TavliPlatform.of(context);
  TavliMenuAction? chosen;

  if (platform.isDesktop && position != null) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final local = overlay.globalToLocal(position);
    final c = Theme.of(context).colorScheme;
    final index = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        local.dx,
        local.dy,
        overlay.size.width - local.dx,
        overlay.size.height - local.dy,
      ),
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavliRadius.compact),
      ),
      items: [
        for (final (i, a) in actions.indexed)
          PopupMenuItem<int>(
            value: i,
            height: 40,
            child: _MenuLabel(action: a),
          ),
      ],
    );
    chosen = index == null ? null : actions[index];
  } else if (platform.isApple) {
    chosen = await showCupertinoModalPopup<TavliMenuAction>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: a.isDestructive,
              onPressed: () => Navigator.of(context).pop(a),
              child: Text(a.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  } else {
    chosen = await showTavliSheet<TavliMenuAction>(
      context,
      title: title,
      builder: (context) => TavliActionList(
        actions: actions,
        onSelected: (a) => Navigator.of(context).pop(a),
      ),
    );
  }
  chosen?.onSelected();
}

/// Akcije kao redovi (ikonica i tekst, visina 52), sadržaj donjeg lista
/// menija na Androidu i Windows-u.
class TavliActionList extends StatelessWidget {
  const TavliActionList({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<TavliMenuAction> actions;
  final ValueChanged<TavliMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in actions)
          InkWell(
            onTap: () => onSelected(a),
            borderRadius: BorderRadius.circular(TavliRadius.field),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TavliSpacing.small,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _MenuLabel(action: a, large: true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.action, this.large = false});

  final TavliMenuAction action;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = action.isDestructive ? c.error : c.onSurface;
    final icon = action.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: large ? 22 : 20,
            color: action.isDestructive ? c.error : c.onSurfaceVariant,
          ),
          SizedBox(width: large ? 14 : 10),
        ],
        Flexible(
          child: Text(
            action.label,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontSize: large ? 16 : 14, color: color),
          ),
        ),
      ],
    );
  }
}

/// Dugme „Još opcija“ (tri tačke) koje otvara [showTavliActionMenu]; na
/// računaru se meni otvara ispod dugmeta.
class TavliMenuButton extends StatelessWidget {
  const TavliMenuButton({
    super.key,
    required this.actions,
    this.title,
    this.semanticLabel = 'Još opcija',
    this.icon = Icons.more_vert,
  });

  final List<TavliMenuAction> actions;
  final String? title;
  final String semanticLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TavliIconButton(
      icon: icon,
      semanticLabel: semanticLabel,
      onPressed: () {
        final box = context.findRenderObject()! as RenderBox;
        unawaited(
          showTavliActionMenu(
            context,
            actions: actions,
            title: title,
            position: box.localToGlobal(box.size.bottomLeft(Offset.zero)),
          ),
        );
      },
    );
  }
}
