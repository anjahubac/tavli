import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/account/account_header.dart';
import '../features/account/sync_banner.dart';
import 'router.dart';

/// Od ove širine tabovi su bočni meni, a Profil je na dnu menija umesto
/// avatara gore desno.
const wideLayoutWidth = 720.0;

/// Donji tabovi na telefonu, bočni meni na širem ekranu (macOS, tablet).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
    if (width >= wideLayoutWidth) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1000,
              labelType: width >= 1000
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: railBranchOrder.indexOf(shell.currentIndex),
              onDestinationSelected: (i) => _select(railBranchOrder[i]),
              trailingAtBottom: true,
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProfileRailItem(extended: width >= 1000),
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
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  const SyncBanner(),
                  Expanded(child: shell),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final navigation = NavigationBar(
      height: largeText ? 64 : 80,
      labelBehavior: largeText
          ? NavigationDestinationLabelBehavior.alwaysHide
          : NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: shell.currentIndex,
      onDestinationSelected: _select,
      destinations: [
        for (final t in tabs)
          NavigationDestination(
            icon: Icon(t.icon),
            selectedIcon: Icon(t.selectedIcon),
            label: t.label,
          ),
      ],
    );
    return Scaffold(
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: largeText
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MediaQuery.removePadding(
                        context: context,
                        removeBottom: true,
                        child: navigation,
                      ),
                      // Natpis taba raste sa tekstom samo do 1,5×, da
                      // navigacija ne pojede ekran pri najvećem tekstu.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.5,
                          child: ExcludeSemantics(
                            child: Text(
                              tabs[shell.currentIndex].label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : navigation,
      ),
    );
  }
}
