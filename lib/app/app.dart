import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../account/auth_controller.dart';
import '../providers.dart';
import 'router.dart';

/// Topla boja tave/terakote.
const _seed = Color(0xFFD2643C);

class TavliApp extends ConsumerStatefulWidget {
  const TavliApp({super.key, this.initialLocation = '/recipes'});

  /// Prva adresa (testovi, duboki link).
  final String initialLocation;

  @override
  ConsumerState<TavliApp> createState() => _TavliAppState();
}

class _TavliAppState extends ConsumerState<TavliApp> {
  final _authChanges = _Refresh();
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;

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
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
    );
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
    // Dok se čita sačuvana sesija (kratko), bez treptanja ekrana prijave.
    if (starting) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        home: const Scaffold(body: SizedBox.expand()),
      );
    }
    return MaterialApp.router(
      title: 'Tavli',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      routerConfig: _router,
    );
  }
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
