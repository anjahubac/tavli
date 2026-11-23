import 'package:flutter/foundation.dart';
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

/// Traka menija aplikacije na računaru.
///
/// macOS: traka na vrhu ekrana. Uvek ima meni aplikacije (O aplikaciji,
/// Podešavanja ⌘, , Sakrij, Zatvori ⌘Q), Uređivanje (Poništi, Iseci,
/// Kopiraj, Nalepi, Izaberi sve, za polje u fokusu) i Prozor; između
/// Uređivanja i Prozora idu [groups] aplikacije.
///
/// Windows: meni u naslovnoj traci prozora (`TavliWindowFrame`): prva
/// grupa (Datoteka) dobija Podešavanja Ctrl+, i Izlaz, iza nje ide
/// Uređivanje, pa ostale grupe i Pomoć (O aplikaciji). Prečice grupa rade
/// sa Ctrl umesto ⌘. Na telefonu samo [child].
class TavliMenuBar extends StatelessWidget {
  const TavliMenuBar({
    super.key,
    this.appName = 'Tavli',
    this.onSettings,
    this.onAbout,
    this.onQuit,
    this.groups = const [],
    this.windowsMenus = true,
    required this.child,
  });

  final String appName;

  /// „Podešavanja…“ (⌘, ili Ctrl+,).
  final VoidCallback? onSettings;

  /// Windows: Pomoć > „O aplikaciji …“. Na macOS-u ga daje sistem.
  final VoidCallback? onAbout;

  /// Windows: Datoteka > „Izlaz“. Na macOS-u ga daje sistem.
  final VoidCallback? onQuit;
  final List<TavliMenuGroup> groups;

  /// Windows: meni i prečice u prozoru. Ekrani prijave ih nemaju (platno).
  final bool windowsMenus;
  final Widget child;

  /// Meniji za naslovnu traku prozora na Windows-u; prazno van Windows-a
  /// ili kada je meni isključen.
  static List<TavliMenuGroup> windowsMenusOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WindowsMenuScope>()?.groups ??
      const [];

  @override
  Widget build(BuildContext context) {
    switch (TavliPlatform.of(context)) {
      case TavliPlatform.macos:
        return PlatformMenuBar(menus: menus(), child: child);
      case TavliPlatform.windows when windowsMenus:
        final groups = windowsGroups();
        return _WindowsMenuScope(
          groups: groups,
          child: CallbackShortcuts(
            bindings: {
              // Uređivanje rade sama polja; ovde su samo prečice aplikacije.
              for (final g in groups)
                if (!identical(g.items, _windowsEdit))
                  for (final c in g.items)
                    if (c?.shortcut case final ShortcutActivator s)
                      s: c!.onSelected,
            },
            child: child,
          ),
        );
      case _:
        return child;
    }
  }

  /// Meniji u prozoru na Windows-u, sa Ctrl prečicama.
  @visibleForTesting
  List<TavliMenuGroup> windowsGroups() {
    final settings = onSettings;
    final quit = onQuit;
    final about = onAbout;
    final app = [
      for (final g in groups)
        TavliMenuGroup(g.label, [
          for (final c in g.items)
            c == null
                ? null
                : TavliMenuCommand(
                    c.label,
                    shortcut: _control(c.shortcut),
                    onSelected: c.onSelected,
                  ),
        ]),
    ];
    final first = app.isEmpty ? null : app.first;
    final file = TavliMenuGroup(first?.label ?? 'Datoteka', [
      ...?first?.items,
      if (settings != null) ...[
        if (first != null && first.items.isNotEmpty) null,
        TavliMenuCommand(
          'Podešavanja',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.comma,
            control: true,
          ),
          onSelected: settings,
        ),
      ],
      if (quit != null) ...[null, TavliMenuCommand('Izlaz', onSelected: quit)],
    ]);
    // Pomoć je jedna i poslednja: „O aplikaciji“ ide iza stavki aplikacije.
    const helpLabel = 'Pomoć';
    final rest = app.skip(1);
    final help = [
      for (final g in rest)
        if (g.label == helpLabel) ...g.items,
    ];
    if (about != null) {
      if (help.isNotEmpty) help.add(null);
      help.add(TavliMenuCommand('O aplikaciji $appName', onSelected: about));
    }
    return [
      if (file.items.isNotEmpty) file,
      TavliMenuGroup('Uređivanje', _windowsEdit),
      for (final g in rest)
        if (g.label != helpLabel) g,
      if (help.isNotEmpty) TavliMenuGroup(helpLabel, help),
    ];
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

/// Prečica sa ⌘ postaje ista prečica sa Ctrl (Windows).
MenuSerializableShortcut? _control(MenuSerializableShortcut? shortcut) =>
    switch (shortcut) {
      SingleActivator(
        :final trigger,
        :final meta,
        :final control,
        :final shift,
        :final alt,
      ) =>
        SingleActivator(
          trigger,
          control: meta || control,
          shift: shift,
          alt: alt,
        ),
      _ => shortcut,
    };

class _WindowsMenuScope extends InheritedWidget {
  const _WindowsMenuScope({required this.groups, required super.child});

  final List<TavliMenuGroup> groups;

  @override
  bool updateShouldNotify(_WindowsMenuScope oldWidget) =>
      !listEquals(groups, oldWidget.groups);
}

/// Uređivanje u prozoru na Windows-u: iste radnje kao na macOS-u, sa
/// prečicama koje polja već imaju (Ctrl+Z, Ctrl+Y, Ctrl+X, Ctrl+C, Ctrl+V,
/// Ctrl+A).
final List<TavliMenuCommand?> _windowsEdit = _edit(control: true);

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
List<TavliMenuCommand?> get _editCommands => _edit(control: false);

List<TavliMenuCommand?> _edit({required bool control}) {
  const cause = SelectionChangedCause.keyboard;
  TavliMenuCommand edit(
    String label,
    LogicalKeyboardKey key,
    Intent intent, {
    bool shift = false,
  }) => TavliMenuCommand(
    label,
    shortcut: SingleActivator(
      key,
      meta: !control,
      control: control,
      shift: shift,
    ),
    onSelected: () {
      final context = primaryFocus?.context;
      if (context != null) Actions.maybeInvoke(context, intent);
    },
  );
  return [
    edit('Poništi', LogicalKeyboardKey.keyZ, const UndoTextIntent(cause)),
    // Windows: Ctrl+Y; macOS: ⇧⌘Z.
    if (control)
      edit('Ponovi', LogicalKeyboardKey.keyY, const RedoTextIntent(cause))
    else
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
