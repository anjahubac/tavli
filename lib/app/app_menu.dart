import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'router.dart';

/// Komanda iz trake menija koju izvršava otvoreni ekran.
enum MenuCommand { newRecipe, searchRecipes }

/// Poslednja komanda iz trake menija; svaki izbor je nov objekat, pa ekran
/// reaguje i kad se ista komanda izabere dvaput.
final class MenuRequest {
  MenuRequest(this.command);

  final MenuCommand command;
}

class MenuRequests extends Notifier<MenuRequest?> {
  @override
  MenuRequest? build() => null;

  void send(MenuCommand command) => state = MenuRequest(command);
}

final menuRequestsProvider = NotifierProvider<MenuRequests, MenuRequest?>(
  MenuRequests.new,
);

/// Dijalog može biti na glavnom navigatoru, a panel na navigatoru taba.
class MenuPopupTracker {
  final root = _PopupObserver();
  final _branches = <String, _PopupObserver>{};

  NavigatorObserver branch(String segment) =>
      _branches.putIfAbsent(segment, _PopupObserver.new);

  bool blocks(Uri location) =>
      root.hasPopup ||
      (_branches[location.pathSegments.firstOrNull]?.hasPopup ?? false);
}

class _PopupObserver extends NavigatorObserver {
  bool hasPopup = false;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    // go_router prosleđuje promene iz navigatora taba i glavnom observeru.
    if (topRoute.navigator == navigator) {
      hasPopup = topRoute is PopupRoute<dynamic>;
    }
  }
}

/// Meni aplikacije: Datoteka (Novi recept ⌘N), Prikaz (tabovi ⌘1–5 po redu
/// iz bočne trake, Pretraži recepte ⌘F) i Podešavanja ⌘, (Profil). Na
/// macOS-u je traka menija, na Windows-u meni u naslovnoj traci prozora sa
/// Ctrl prečicama; [windowsMenus] je `false` dok korisnik nije prijavljen.
Widget appMenuBar(
  GoRouter router,
  WidgetRef ref,
  MenuPopupTracker popups,
  Widget child, {
  bool windowsMenus = true,
  VoidCallback? onQuit,
}) {
  final context = ref.context;
  SingleActivator cmd(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: true);
  void unlessPopup(VoidCallback action) {
    if (!popups.blocks(router.state.uri)) action();
  }

  void recipes(MenuCommand command) {
    unlessPopup(() {
      router.go('/recipes');
      // Posle prelaska na Recepte, da ekran već sluša.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || router.state.uri.path != '/recipes') return;
        unlessPopup(
          () => ref.read(menuRequestsProvider.notifier).send(command),
        );
      });
    });
  }

  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];
  const tabs = [
    ('Početna', homeLocation),
    ('Plan', '/plan'),
    ('Nabavka', '/shopping'),
    ('Recepti', '/recipes'),
    ('Ostava', '/pantry'),
  ];
  return TavliMenuBar(
    windowsMenus: windowsMenus,
    onQuit: onQuit,
    onAbout: () => unlessPopup(
      () => unawaited(
        showTavliDialog<void>(
          router.routerDelegate.navigatorKey.currentContext ?? context,
          title: 'O aplikaciji Tavli',
          message: 'Recepti, plan obroka, nabavka i ostava na jednom mestu.',
          actions: [const TavliDialogAction('Zatvori', null)],
        ),
      ),
    ),
    onSettings: () => unlessPopup(() {
      if (router.state.uri.pathSegments.firstOrNull != 'profile') {
        unawaited(router.push('/profile'));
      }
    }),
    groups: [
      TavliMenuGroup('Datoteka', [
        TavliMenuCommand(
          'Novi recept',
          shortcut: cmd(LogicalKeyboardKey.keyN),
          onSelected: () => recipes(MenuCommand.newRecipe),
        ),
      ]),
      TavliMenuGroup('Prikaz', [
        for (final (i, (label, path)) in tabs.indexed)
          TavliMenuCommand(
            label,
            shortcut: cmd(digits[i]),
            onSelected: () => unlessPopup(() => router.go(path)),
          ),
        null,
        TavliMenuCommand(
          'Pretraži recepte',
          shortcut: cmd(LogicalKeyboardKey.keyF),
          onSelected: () => recipes(MenuCommand.searchRecipes),
        ),
      ]),
    ],
    child: child,
  );
}
