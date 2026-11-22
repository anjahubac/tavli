import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../platform.dart';
import 'tavli_action_menu.dart';

/// Meni na desni klik (računar): [showTavliActionMenu] na mestu klika, sa
/// istim radnjama koje ekran već nudi (dugi pritisak, dugmad u detalju).
/// Na telefonu samo [child]. Prazan [actions] ne otvara ništa.
class TavliContextMenu extends StatelessWidget {
  const TavliContextMenu({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<TavliMenuAction> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty || !TavliPlatform.of(context).isDesktop) return child;
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapUp: (details) => unawaited(
        showTavliActionMenu(
          context,
          actions: actions,
          position: details.globalPosition,
        ),
      ),
      child: child,
    );
  }
}
