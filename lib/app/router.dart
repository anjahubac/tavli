import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_shell.dart';
import 'placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/recipes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        for (final tab in tabs)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: tab.path,
                builder: (context, state) =>
                    PlaceholderScreen(title: tab.label, icon: tab.icon),
              ),
            ],
          ),
      ],
    ),
  ],
);

class TabSpec {
  const TabSpec(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const tabs = [
  TabSpec('/recipes', 'Recepti', Icons.menu_book_outlined, Icons.menu_book),
  TabSpec('/plan', 'Plan', Icons.calendar_month_outlined, Icons.calendar_month),
  TabSpec('/pantry', 'Ostava', Icons.kitchen_outlined, Icons.kitchen),
  TabSpec(
    '/shopping',
    'Kupovina',
    Icons.shopping_basket_outlined,
    Icons.shopping_basket,
  ),
  TabSpec('/profile', 'Profil', Icons.person_outline, Icons.person),
];
