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

/// Traka menija na macOS-u: Datoteka (Novi recept ⌘N), Prikaz (tabovi
/// ⌘1–5 po redu iz bočne trake, Pretraži recepte ⌘F) i Podešavanja ⌘,
/// (Profil).
Widget appMenuBar(GoRouter router, WidgetRef ref, Widget child) {
  SingleActivator cmd(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: true);
  void recipes(MenuCommand command) {
    router.go('/recipes');
    // Posle prelaska na Recepte, da ekran već sluša.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(menuRequestsProvider.notifier).send(command),
    );
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
    onSettings: () {
      if (router.state.matchedLocation != '/profile') {
        unawaited(router.push('/profile'));
      }
    },
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
            onSelected: () => router.go(path),
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
