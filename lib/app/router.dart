import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/recipes/from_name_screen.dart';
import '../features/recipes/from_photo_screen.dart';
import '../features/recipes/recipe_chat_screen.dart';
import '../features/recipes/recipe_form_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/settings/ai_keys_screen.dart';
import '../features/settings/animations_gallery_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/profile_screen.dart';
import 'animations/empty_fridge.dart';
import 'animations/intro_motif.dart';
import 'home_shell.dart';
import 'placeholder_screen.dart';

final appRouter = createRouter();

/// Pravi novi router (testovi prave svoj, da stanje ne prelazi iz testa u test).
GoRouter createRouter({String initialLocation = '/recipes'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recipes',
              builder: (context, state) => const RecipesScreen(),
              routes: [
                GoRoute(
                  path: 'new/name',
                  builder: (context, state) => const FromNameScreen(),
                ),
                GoRoute(
                  path: 'new/photo',
                  builder: (context, state) => const FromPhotoScreen(),
                ),
                GoRoute(
                  path: 'new/manual',
                  builder: (context, state) => const RecipeFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) {
                    final child = RecipeRoute(id: state.pathParameters['id']!);
                    // Na širokom ekranu se samo menja izbor u listi.
                    return MediaQuery.sizeOf(context).width >= 1100
                        ? NoTransitionPage(key: state.pageKey, child: child)
                        : MaterialPage(key: state.pageKey, child: child);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) =>
                          RecipeFormScreen(id: state.pathParameters['id']),
                    ),
                    GoRoute(
                      path: 'chat',
                      builder: (context, state) =>
                          RecipeChatScreen(id: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/plan',
              builder: (context, state) =>
                  PlaceholderScreen(title: tabs[1].label, icon: tabs[1].icon),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pantry',
              builder: (context, state) => const EmptyStateScreen(
                appBarTitle: 'Ostava',
                art: EmptyFridge(),
                title: 'Ostava je prazna',
                body: 'Vreme je za nabavku',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shopping',
              builder: (context, state) => const EmptyStateScreen(
                appBarTitle: 'Kupovina',
                art: IntroMotif(size: 200),
                title: 'Lista je prazna',
                body: 'Sastojci koji ti nedostaju za recept pojaviće se ovde.',
              ),
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
                GoRoute(
                  path: 'appearance',
                  builder: (context, state) => const AppearanceScreen(),
                ),
                GoRoute(
                  path: 'animations',
                  builder: (context, state) => const AnimationsGalleryScreen(),
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
