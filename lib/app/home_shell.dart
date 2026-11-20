import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../account/auth_controller.dart';
import '../domain/account.dart';
import '../features/account/sync_banner.dart';
import 'router.dart';

/// Od ove širine tabovi su bočni meni, a Profil je na dnu menija umesto
/// avatara gore desno.
const wideLayoutWidth = 720.0;

enum _NavigationLayout { bottom, largeText, rail }

/// Tabovi u redosledu grana; Početna je u sredini donje trake, a u bočnoj
/// traci prva.
final List<TavliDestination> _destinations = [
  for (final t in tabs)
    TavliDestination(
      icon: t.icon,
      label: t.label,
      home: t.path == homeLocation,
    ),
];

/// Inicijali prijavljenog člana za avatar u gornjoj i bočnoj traci.
String profileInitials(WidgetRef ref) {
  final auth = ref.watch(authControllerProvider);
  final name = auth is SignedIn ? auth.account.displayName ?? '' : '';
  return initials(name);
}

/// Tabovi kao na platnu: donja navigacija na telefonu, bočna traka sa
/// Početnom na vrhu i Profilom na dnu na širem ekranu (macOS, tablet).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _railFocus = FocusNode(
    debugLabel: 'Navigation rail',
    canRequestFocus: false,
  );
  final _bottomFocus = FocusNode(
    debugLabel: 'Bottom navigation',
    canRequestFocus: false,
  );
  final _contentFocus = FocusNode(
    debugLabel: 'Tab content',
    skipTraversal: true,
  );
  _NavigationLayout? _layout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final previous = _layout;
    final next = MediaQuery.sizeOf(context).width >= wideLayoutWidth
        ? _NavigationLayout.rail
        : MediaQuery.textScalerOf(context).scale(16) > 20
        ? _NavigationLayout.largeText
        : _NavigationLayout.bottom;
    _layout = next;
    final previousFocus = previous == _NavigationLayout.rail
        ? _railFocus
        : _bottomFocus;
    if (previous != null && previous != next && previousFocus.hasFocus) {
      // Ako se fokusirani meni zameni drugim, tastatura se vraća na sadržaj
      // trenutnog taba. Fokus koji je već u sadržaju ostaje tamo.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _layout == next) _contentFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _railFocus.dispose();
    _bottomFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _select(int index) => widget.shell.goBranch(
    index,
    initialLocation: index == widget.shell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.shell.currentIndex;
    final wide = _layout == _NavigationLayout.rail;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Focus.withExternalFocusNode(
              focusNode: _railFocus,
              child: TavliNavigation(
                layout: TavliNavigationLayout.side,
                destinations: _destinations,
                selectedIndex: selected,
                onSelected: _select,
                initials: profileInitials(ref),
                onProfile: () => context.push('/profile'),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: Focus.withExternalFocusNode(
              focusNode: _contentFocus,
              child: Column(
                children: [
                  const SyncBanner(),
                  Expanded(child: widget.shell),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : Focus.withExternalFocusNode(
              focusNode: _bottomFocus,
              child: _layout == _NavigationLayout.largeText
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: TavliColors.of(context).line),
                        ),
                      ),
                      child: _LargeTextNavigation(
                        selected: selected,
                        onSelected: _select,
                      ),
                    )
                  : TavliNavigation(
                      layout: TavliNavigationLayout.bottom,
                      destinations: _destinations,
                      selectedIndex: selected,
                      onSelected: _select,
                    ),
            ),
    );
  }
}

/// Dva reda na krajevima ostavljaju mesta za pune nazive, a Početna ostaje
/// u sredini. Čitač ekrana i tastatura prate redosled tabova.
class _LargeTextNavigation extends StatelessWidget {
  const _LargeTextNavigation({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Glavna navigacija',
      container: true,
      explicitChildNodes: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              children: [
                for (final column in const [
                  [0, 1],
                  [2],
                  [3, 4],
                ])
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final index in column)
                          _LargeTextDestination(
                            index: index,
                            selected: index == selected,
                            onTap: () => onSelected(index),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeTextDestination extends StatelessWidget {
  const _LargeTextDestination({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final tab = tabs[index];
    final order = index.toDouble();
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: selected,
          sortKey: OrdinalSortKey(order),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              color: selected ? colors.secondaryContainer : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TavliIcon(tab.icon, size: 20, color: foreground),
                      Text(
                        tab.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
