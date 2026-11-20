import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/account/account_header.dart';
import '../features/account/sync_banner.dart';
import 'router.dart';

/// Od ove širine tabovi su bočni meni, a Profil je na dnu menija umesto
/// avatara gore desno.
const wideLayoutWidth = 720.0;

enum _NavigationLayout { bottom, largeText, rail }

/// Donji tabovi na telefonu, bočni meni na širem ekranu (macOS, tablet).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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
    final extended = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Focus.withExternalFocusNode(
              focusNode: _railFocus,
              child: NavigationRail(
                extended: extended,
                scrollable: true,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: railBranchOrder.indexOf(selected),
                onDestinationSelected: (i) => _select(railBranchOrder[i]),
                trailingAtBottom: true,
                trailing: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ProfileRailItem(extended: extended),
                ),
                destinations: [
                  for (final t in railBranchOrder.map((i) => tabs[i]))
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          if (wide)
            const VerticalDivider(width: 1)
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: _layout == _NavigationLayout.largeText
                    ? _LargeTextNavigation(
                        selected: selected,
                        onSelected: _select,
                      )
                    : NavigationBar(
                        selectedIndex: selected,
                        onDestinationSelected: _select,
                        destinations: [
                          for (final t in tabs)
                            NavigationDestination(
                              icon: Icon(t.icon),
                              selectedIcon: Icon(t.selectedIcon),
                              label: t.label,
                            ),
                        ],
                      ),
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
                      Icon(
                        selected ? tab.selectedIcon : tab.icon,
                        size: 20,
                        color: foreground,
                      ),
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
