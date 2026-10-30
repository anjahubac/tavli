import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/theme_choice.dart';
import 'animations/intro_overlay.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class TavliApp extends ConsumerWidget {
  const TavliApp({super.key, this.router, this.intro = true});

  /// Za testove; inače [appRouter].
  final GoRouter? router;

  /// Uvodni ekran pri pokretanju (testovi ga isključuju).
  final bool intro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Tavli',
      debugShowCheckedModeBanner: false,
      theme: buildTavliTheme(choice.theme, Brightness.light),
      darkTheme: buildTavliTheme(choice.theme, Brightness.dark),
      themeMode: switch (choice.mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router ?? appRouter,
      builder: (context, child) =>
          IntroOverlay(enabled: intro, child: child ?? const SizedBox()),
    );
  }
}
