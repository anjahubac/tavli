import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/ai_keys_screen.dart';
import '../features/settings/profile_screen.dart';
import 'home_shell.dart';
import 'placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/recipes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        for (final tab in tabs.where((t) => t.path != '/profile'))
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: tab.path,
                builder: (context, state) =>
                    PlaceholderScreen(title: tab.label, icon: tab.icon),
              ),
            ],
          ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'ai-keys',
                  builder: (context, state) => const AiKeysScreen(),
                ),
              ],
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
