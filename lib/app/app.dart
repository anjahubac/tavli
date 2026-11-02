import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/auth_controller.dart';
import '../domain/theme_choice.dart';
import '../features/account/sync_banner.dart';
import '../providers.dart';
import 'animations/intro_overlay.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class TavliApp extends ConsumerStatefulWidget {
  const TavliApp({
    super.key,
    this.initialLocation = '/plan',
    this.intro = true,
  });

  /// Testovi mogu isključiti motiv tokom stvarnog učitavanja sesije.
  final bool intro;

  /// Prva adresa (testovi, duboki link).
  final String initialLocation;

  @override
  ConsumerState<TavliApp> createState() => _TavliAppState();
}

class _TavliAppState extends ConsumerState<TavliApp> {
  final _authChanges = _Refresh();
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _router = createRouter(
      initialLocation: widget.initialLocation,
      auth: () => ref.read(authControllerProvider),
      refresh: _authChanges,
    );
    ref.listenManual(authControllerProvider, (_, _) => _authChanges.ping());
    // Drži engine za slanje živim dok je nalog prijavljen.
    ref.listenManual(syncEngineProvider, (_, _) {}, fireImmediately: true);
    ref.listenManual(movedSavedProvider, (_, next) {
      if (next.value case final n? when n > 0) {
        // Posle sledećeg okvira: aplikacija možda još prelazi sa ekrana
        // pokretanja na router.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _messenger.currentState?.showSnackBar(
            const SnackBar(content: Text(dataMovedText)),
          ),
        );
      }
    });
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    unawaited(
      Future.microtask(ref.read(authControllerProvider.notifier).start),
    );
  }

  void _onResume() {
    unawaited(ref.read(authControllerProvider.notifier).restoreSession());
    unawaited(ref.read(syncEngineProvider)?.onResume());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    _authChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starting = ref.watch(
      authControllerProvider.select((s) => s is Starting),
    );
    final choice = ref.watch(themeControllerProvider);
    final theme = buildTavliTheme(choice.theme, Brightness.light);
    final darkTheme = buildTavliTheme(choice.theme, Brightness.dark);
    final mode = switch (choice.mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
    // Dok se čita sačuvana sesija (kratko), bez treptanja ekrana prijave.
    if (starting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeAnimationStyle: AnimationStyle.noAnimation,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        home: Scaffold(
          body: widget.intro ? const IntroScreen() : const SizedBox.expand(),
        ),
      );
    }
    return MaterialApp.router(
      title: 'Tavli',
      themeAnimationStyle: AnimationStyle.noAnimation,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      routerConfig: _router,
      scaffoldMessengerKey: _messenger,
    );
  }
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
