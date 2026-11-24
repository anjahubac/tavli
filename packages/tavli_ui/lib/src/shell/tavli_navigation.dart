import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../icons/tavli_icons.dart';
import '../motion/motion.dart';
import '../platform.dart';
import '../theme/tavli_colors.dart';
import 'shell_parts.dart';
import 'tavli_window_frame.dart';

/// Jedan tab glavne navigacije.
@immutable
class TavliDestination {
  const TavliDestination({
    required this.icon,
    required this.label,
    this.home = false,
  });

  /// Ista ikonica za izabran i neizabran tab, kao na platnu; izabran tab
  /// se razlikuje bojom i oznakom iza ikonice.
  final TavliIconData icon;
  final String label;

  /// Početna: u bočnoj navigaciji stoji prva, a u donjoj tamo gde je u listi
  /// (u sredini).
  final bool home;
}

/// Donja navigacija na telefonu ili bočna na računaru.
enum TavliNavigationLayout { bottom, side }

/// Glavna navigacija sa 5 tabova.
///
/// Telefon: donja traka, Početna u sredini, oznaka izabranog taba 60 x 32.
/// Na iOS-u traka je viša, sa prostorom za home indikator.
/// Računar: bočna traka širine 220, Početna prva, avatar i Profil na dnu,
/// bez oznaka prečica. Na macOS-u vrh trake ostaje prazan za dugmad prozora.
///
/// [selectedIndex] i [onSelected] uvek se odnose na redosled iz
/// [destinations], bez obzira na to kako je bočna traka poređana.
class TavliNavigation extends StatelessWidget {
  const TavliNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.layout,
    this.initials,
    this.onProfile,
    this.profileSelected = false,
  });

  final List<TavliDestination> destinations;

  /// Izabrani tab; `null` kada je otvoren ekran van tabova (Profil).
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  /// Bez zadatog rasporeda: bočna na računaru i na ekranu širem od 720,
  /// inače donja.
  final TavliNavigationLayout? layout;

  /// Inicijali za red Profil na dnu bočne trake; donja traka ih ne koristi
  /// (avatar je u `TavliAppBar`).
  final String? initials;
  final VoidCallback? onProfile;
  final bool profileSelected;

  /// Širina od koje telefon/tablet dobija bočnu navigaciju.
  static const sideBreakpoint = 720.0;

  TavliNavigationLayout _layout(BuildContext context) =>
      layout ??
      (TavliPlatform.of(context).isDesktop ||
              MediaQuery.sizeOf(context).width >= sideBreakpoint
          ? TavliNavigationLayout.side
          : TavliNavigationLayout.bottom);

  @override
  Widget build(BuildContext context) => switch (_layout(context)) {
    TavliNavigationLayout.bottom => _BottomBar(nav: this),
    TavliNavigationLayout.side => _SideBar(nav: this),
  };
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.nav});

  final TavliNavigation nav;

  @override
  Widget build(BuildContext context) {
    final ios = TavliPlatform.of(context) == TavliPlatform.ios;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = math.max(inset, ios ? 30.0 : 12.0);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Glavna navigacija',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: TavliColors.of(context).line)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, bottom),
          // Oznake tabova rastu najviše do 1,3x, da traka ostane iste visine
          // i sa uvećanim tekstom; čitač ekrana i dalje čita pun naziv.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, d) in nav.destinations.indexed)
                  Expanded(
                    child: _BottomItem(
                      destination: d,
                      selected: i == nav.selectedIndex,
                      onTap: () => nav.onSelected(i),
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

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final TavliDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = selected ? c.onPrimaryContainer : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: TavliMotion.duration(context, TavliMotion.feedback),
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? c.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: TavliIcon(destination.icon, size: 22, color: fg),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({required this.nav});

  final TavliNavigation nav;

  @override
  Widget build(BuildContext context) {
    final platform = TavliPlatform.of(context);
    final windows = platform == TavliPlatform.windows;
    final macos = platform == TavliPlatform.macos;
    // Prostor za semafore i povlačenje prozora ostaje iznad skrola.
    final titleBar = macos
        ? TavliWindowFrame.macosTitleBarInsetOf(context)
        : 0.0;
    final top = titleBar > 0
        ? 0.0
        : 12.0 + (macos ? MediaQuery.paddingOf(context).top : 0);
    final order = [
      for (final (i, d) in nav.destinations.indexed)
        if (d.home) i,
      for (final (i, d) in nav.destinations.indexed)
        if (!d.home) i,
    ];
    final initials = nav.initials;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Glavna navigacija',
      child: Container(
        width: 220,
        padding: EdgeInsets.only(top: titleBar),
        decoration: BoxDecoration(
          color: shellSurface(context),
          border: Border(
            right: BorderSide(color: TavliColors.of(context).line),
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                windows ? 8 : 10,
                top,
                windows ? 8 : 10,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  for (final i in order)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SideItem(
                        selected: i == nav.selectedIndex,
                        onTap: () => nav.onSelected(i),
                        label: nav.destinations[i].label,
                        leading: TavliIcon(nav.destinations[i].icon, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    windows ? 8 : 10,
                    8,
                    windows ? 8 : 10,
                    12,
                  ),
                  child: initials == null
                      ? const SizedBox.shrink()
                      : _SideItem(
                          selected: nav.profileSelected,
                          onTap: nav.onProfile,
                          label: 'Profil',
                          profile: true,
                          leading: ProfileAvatar(initials: initials, size: 30),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.selected,
    required this.onTap,
    required this.label,
    required this.leading,
    this.profile = false,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String label;
  final Widget leading;
  final bool profile;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final windows = TavliPlatform.of(context) == TavliPlatform.windows;
    final radius = BorderRadius.circular(windows ? 6 : 10);
    final weight = selected
        ? FontWeight.w700
        : (profile ? FontWeight.w600 : FontWeight.w500);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.primaryContainer : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: profile ? 44 : (windows ? 38 : 40),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: profile ? 8 : 12),
              child: Row(
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      color: selected
                          ? c.onPrimaryContainer
                          : c.onSurfaceVariant,
                    ),
                    child: leading,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: weight,
                        color: selected ? c.onPrimaryContainer : c.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
