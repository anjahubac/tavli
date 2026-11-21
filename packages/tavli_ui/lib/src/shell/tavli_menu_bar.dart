import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../platform.dart';

/// Stavka u traci menija: naziv, prečica i radnja.
class TavliMenuCommand {
  const TavliMenuCommand(this.label, {this.shortcut, required this.onSelected});

  final String label;

  /// Npr. `SingleActivator(LogicalKeyboardKey.keyN, meta: true)` za ⌘N.
  final MenuSerializableShortcut? shortcut;
  final VoidCallback onSelected;
}

/// Meni u traci menija; `null` u [items] je razdelnik.
class TavliMenuGroup {
  const TavliMenuGroup(this.label, this.items);

  final String label;
  final List<TavliMenuCommand?> items;
}

/// Traka menija na vrhu ekrana na macOS-u.
///
/// Uvek ima meni aplikacije (O aplikaciji, Podešavanja ⌘, , Sakrij, Zatvori
/// ⌘Q), Uređivanje (Poništi, Iseci, Kopiraj, Nalepi, Izaberi sve, za
/// polje u fokusu) i Prozor; između Uređivanja i Prozora idu [groups]
/// aplikacije. Na ostalim platformama samo [child].
class TavliMenuBar extends StatelessWidget {
  const TavliMenuBar({
    super.key,
    this.appName = 'Tavli',
    this.onSettings,
    this.groups = const [],
    required this.child,
  });

  final String appName;

  /// „Podešavanja…“ (⌘,) u meniju aplikacije.
  final VoidCallback? onSettings;
  final List<TavliMenuGroup> groups;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (TavliPlatform.of(context) != TavliPlatform.macos) return child;
    return PlatformMenuBar(menus: menus(), child: child);
  }

  /// Meniji kako ih traka šalje sistemu (i testovima).
  @visibleForTesting
  List<PlatformMenuItem> menus() {
    // Sistemske stavke postoje samo kad aplikacija stvarno radi na macOS-u
    // (u testovima i galeriji tema samo glumi macOS).
    List<PlatformMenuItem> provided(List<PlatformProvidedMenuItemType> types) {
      final members = [
        for (final type in types)
          if (PlatformProvidedMenuItem.hasMenu(type))
            PlatformProvidedMenuItem(type: type),
      ];
      return [if (members.isNotEmpty) PlatformMenuItemGroup(members: members)];
    }

    final settings = onSettings;
    final window = [
      ...provided([
        PlatformProvidedMenuItemType.minimizeWindow,
        PlatformProvidedMenuItemType.zoomWindow,
        PlatformProvidedMenuItemType.toggleFullScreen,
      ]),
      ...provided([PlatformProvidedMenuItemType.arrangeWindowsInFront]),
    ];
    return [
      PlatformMenu(
        label: appName,
        menus: [
          ...provided([PlatformProvidedMenuItemType.about]),
          if (settings != null)
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Podešavanja…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: settings,
                ),
              ],
            ),
          ...provided([
            PlatformProvidedMenuItemType.hide,
            PlatformProvidedMenuItemType.hideOtherApplications,
            PlatformProvidedMenuItemType.showAllApplications,
          ]),
          ...provided([PlatformProvidedMenuItemType.quit]),
        ],
      ),
      PlatformMenu(label: 'Uređivanje', menus: _sections(_editCommands)),
      for (final g in groups)
        PlatformMenu(label: g.label, menus: _sections(g.items)),
      if (window.isNotEmpty) PlatformMenu(label: 'Prozor', menus: window),
    ];
  }
}

/// Stavke menija u grupama između razdelnika (`null`).
List<PlatformMenuItem> _sections(List<TavliMenuCommand?> items) {
  final out = <PlatformMenuItem>[];
  var run = <PlatformMenuItem>[];
  void flush() {
    if (run.isNotEmpty) out.add(PlatformMenuItemGroup(members: run));
    run = [];
  }

  for (final item in items) {
    if (item == null) {
      flush();
    } else {
      run.add(
        PlatformMenuItem(
          label: item.label,
          shortcut: item.shortcut,
          onSelected: item.onSelected,
        ),
      );
    }
  }
  flush();
  return out;
}

/// Sistemska traka menija preuzima ove prečice pre polja, pa ih ona šalje
/// polju u fokusu kao iste radnje koje bi taster pokrenuo.
List<TavliMenuCommand?> get _editCommands {
  const cause = SelectionChangedCause.keyboard;
  TavliMenuCommand edit(
    String label,
    LogicalKeyboardKey key,
    Intent intent, {
    bool shift = false,
  }) => TavliMenuCommand(
    label,
    shortcut: SingleActivator(key, meta: true, shift: shift),
    onSelected: () {
      final context = primaryFocus?.context;
      if (context != null) Actions.maybeInvoke(context, intent);
    },
  );
  return [
    edit('Poništi', LogicalKeyboardKey.keyZ, const UndoTextIntent(cause)),
    edit(
      'Ponovi',
      LogicalKeyboardKey.keyZ,
      const RedoTextIntent(cause),
      shift: true,
    ),
    null,
    edit(
      'Iseci',
      LogicalKeyboardKey.keyX,
      const CopySelectionTextIntent.cut(cause),
    ),
    edit('Kopiraj', LogicalKeyboardKey.keyC, CopySelectionTextIntent.copy),
    edit('Nalepi', LogicalKeyboardKey.keyV, const PasteTextIntent(cause)),
    edit(
      'Izaberi sve',
      LogicalKeyboardKey.keyA,
      const SelectAllTextIntent(cause),
    ),
  ];
}
