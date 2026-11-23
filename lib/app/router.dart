import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../account/auth_controller.dart';
import '../domain/voice_draft.dart';
import '../features/account/household_setup_screen.dart';
import '../features/account/household_share_screen.dart';
import '../features/account/name_screen.dart';
import '../features/account/sign_in_screen.dart';
import '../features/account/sign_up_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pantry/pantry_photo_screen.dart';
import '../features/pantry/pantry_screen.dart';
import '../features/planning/plan_preview_screen.dart';
import '../features/planning/plan_screen.dart';
import '../features/planning/plan_setup_screen.dart';
import '../features/recipes/cook_from_pantry_screen.dart';
import '../features/recipes/cooking_mode_screen.dart';
import '../features/recipes/from_name_screen.dart';
import '../features/recipes/from_photo_screen.dart';
import '../features/recipes/recipe_chat_screen.dart';
import '../features/recipes/recipe_form_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/recipes/voice_recipe_screen.dart';
import '../features/settings/ai_keys_screen.dart';
import '../features/settings/animations_gallery_screen.dart';
import '../features/settings/appearance_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/tastes/tastes_screen.dart';
import '../features/shopping/shopping_screen.dart';
import 'app_menu.dart';
import 'home_shell.dart';

/// Glavni ekran: Početna, srednji tab (021 FR-002).
const homeLocation = '/home';

/// Galerija komponenti (Profil > Komponente); postoji samo u debug verziji.
const componentsPath = '/components';

/// "Registracija" (sign up); "Prijava" je [signInPath].
const signUpPath = '/sign-up';
const signInPath = '/sign-in';

/// Korak "Tvoje domaćinstvo" posle imena.
const householdSetupPath = '/sign-in/household';

/// Kuda vodi stanje prijave: bez naloga samo "Prijava" ili "Registracija",
/// posle poslatog koda "Upiši kod" (na "Prijava"), posle poslatog mejla za
/// potvrdu "Proveri mejl" (na "Registracija"), bez imena samo korak sa
/// imenom (FR-001), pa korak "Tvoje domaćinstvo". Tražena adresa se pamti u `from`; Početna
/// ([homeLocation]) je podrazumevana pa se ne pamti.
/// Uz [debugTools] galerija komponenti se otvara i bez prijave.
String? authRedirect(AuthState auth, Uri uri, {bool debugTools = kDebugMode}) {
  final path = uri.path;
  if (debugTools && path == componentsPath) return null;
  final from = uri.queryParameters['from'];
  String withFrom(String target) {
    final back = _isAuthPath(path) ? from : uri.toString();
    return back == null || back == homeLocation
        ? target
        : Uri(path: target, queryParameters: {'from': back}).toString();
  }

  return switch (auth) {
    Starting() || SignedOut() =>
      path == signInPath || path == signUpPath ? null : withFrom(signInPath),
    CodeSent() => path == signInPath ? null : withFrom(signInPath),
    ConfirmSent() => path == signUpPath ? null : withFrom(signUpPath),
    NeedsName() => path == '/sign-in/name' ? null : withFrom('/sign-in/name'),
    NeedsHousehold() =>
      path == householdSetupPath ? null : withFrom(householdSetupPath),
    SignedIn() => _isAuthPath(path) ? (from ?? homeLocation) : null,
  };
}

bool _isAuthPath(String path) =>
    path.startsWith(signInPath) || path.startsWith(signUpPath);

/// Pravi novi router (testovi prave svoj, da stanje ne prelazi iz testa u
/// test). [auth] daje trenutno stanje prijave, [refresh] javlja promene.
/// [debugTools] uključuje ekrane za razvoj; u verziji za objavu ih nema.
GoRouter createRouter({
  String initialLocation = homeLocation,
  AuthState Function()? auth,
  Listenable? refresh,
  MenuPopupTracker? menuPopups,
  bool debugTools = kDebugMode,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: refresh,
  observers: [?menuPopups?.root],
  redirect: auth == null
      ? null
      : (context, state) =>
            authRedirect(auth(), state.uri, debugTools: debugTools),
  routes: [
    if (debugTools)
      GoRoute(
        path: componentsPath,
        builder: (context, state) => TavliGallery(
          // Otvorena direktnom adresom nema kuda nazad, pa vodi na Plan.
          onClose: () => context.canPop() ? context.pop() : context.go('/plan'),
        ),
      ),
    GoRoute(
      path: signInPath,
      builder: (context, state) => const SignInScreen(),
      routes: [
        GoRoute(path: 'name', builder: (context, state) => const NameScreen()),
        GoRoute(
          path: 'household',
          builder: (context, state) => const HouseholdSetupScreen(),
        ),
      ],
    ),
    GoRoute(
      path: signUpPath,
      builder: (context, state) => const SignUpScreen(),
    ),
    // Režim kuvanja je preko celog ekrana, bez glavne navigacije (021 FR-010).
    GoRoute(
      path: '/cook/recipe/:id',
      builder: (context, state) =>
          RecipeCookingRoute(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/cook/meal/:planId/:entryId',
      builder: (context, state) => MealCookingRoute(
        planId: state.pathParameters['planId']!,
        entryId: state.pathParameters['entryId']!,
      ),
    ),
    // Profil i podešavanja su iznad tabova; otvaraju se preko avatara. Na
    // širokom ekranu ostaju u okviru sa bočnom navigacijom, kao na platnu.
    ShellRoute(
      builder: (context, state, child) => ProfileShell(child: child),
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
              path: 'household-share',
              builder: (context, state) => const HouseholdShareScreen(),
            ),
            GoRoute(
              path: 'appearance',
              builder: (context, state) => const AppearanceScreen(),
            ),
            GoRoute(
              path: 'tastes',
              builder: (context, state) => const TastesScreen(),
            ),
            GoRoute(
              path: 'animations',
              builder: (context, state) => const AnimationsGalleryScreen(),
            ),
          ],
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          observers: [?menuPopups?.branch('plan')],
          routes: [
            GoRoute(
              path: '/plan',
              builder: (context, state) => const PlanScreen(),
              routes: [
                GoRoute(
                  path: ':planId/entries/:entryId',
                  builder: (context, state) => MealEntryScreen(
                    planId: state.pathParameters['planId']!,
                    entryId: state.pathParameters['entryId']!,
                  ),
                ),
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const PlanSetupScreen(),
                  routes: [
                    GoRoute(
                      path: 'preview',
                      builder: (context, state) => const PlanPreviewScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [?menuPopups?.branch('shopping')],
          routes: [
            GoRoute(
              path: '/shopping',
              builder: (context, state) => const ShoppingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [?menuPopups?.branch('home')],
          routes: [
            GoRoute(
              path: homeLocation,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [?menuPopups?.branch('recipes')],
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
                  builder: (context, state) => FromPhotoScreen(
                    initialPhoto: switch (state.extra) {
                      final Uint8List photo => photo,
                      _ => null,
                    },
                  ),
                ),
                GoRoute(
                  path: 'new/manual',
                  builder: (context, state) => RecipeFormScreen(
                    draft: switch (state.extra) {
                      final VoiceDraft draft => draft,
                      _ => null,
                    },
                  ),
                ),
                GoRoute(
                  path: 'new/voice',
                  builder: (context, state) => const VoiceRecipeScreen(),
                ),
                // Pre ':id', da „from-pantry“ ne bude id recepta.
                GoRoute(
                  path: 'from-pantry',
                  builder: (context, state) => const CookFromPantryScreen(),
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
          observers: [?menuPopups?.branch('pantry')],
          routes: [
            GoRoute(
              path: '/pantry',
              builder: (context, state) => const PantryScreen(),
              routes: [
                GoRoute(
                  path: 'photo',
                  builder: (context, state) => PantryPhotoScreen(
                    initialPhoto: switch (state.extra) {
                      final Uint8List photo => photo,
                      _ => null,
                    },
                  ),
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
  const TabSpec(this.path, this.label, this.icon);

  final String path;
  final String label;

  /// Ikonica sa platna; izabran tab ima istu ikonicu, drugom bojom.
  final TavliIconData icon;
}

const tabs = [
  TabSpec('/plan', 'Plan', TavliIcons.plan),
  TabSpec('/shopping', 'Nabavka', TavliIcons.shopping),
  TabSpec(homeLocation, 'Početna', TavliIcons.home),
  TabSpec('/recipes', 'Recepti', TavliIcons.recipes),
  TabSpec('/pantry', 'Ostava', TavliIcons.pantry),
];

/// Bočni meni (širok ekran): Početna na vrhu, ostali tabovi istim redom kao
/// dole. Vrednosti su indeksi u [tabs], odnosno grane rutera.
final List<int> railBranchOrder = () {
  final home = tabs.indexWhere((t) => t.path == homeLocation);
  return [
    home,
    for (var i = 0; i < tabs.length; i++)
      if (i != home) i,
  ];
}();
