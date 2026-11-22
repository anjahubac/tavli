import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../account/auth_controller.dart';
import '../domain/theme_choice.dart';
import '../features/account/sync_banner.dart';
import '../providers.dart';
import 'animations/intro_overlay.dart';
import 'app_menu.dart';
import 'router.dart';
import 'theme_controller.dart';

const _macosWindow = MethodChannel('tavli/macos_window');

class TavliApp extends ConsumerStatefulWidget {
  const TavliApp({
    super.key,
    this.initialLocation = homeLocation,
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
  final _menuPopups = MenuPopupTracker();
  late final GoRouter _router;
  late final AppLifecycleListener _lifecycle;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final bool _observesMacosWindow;
  bool? _macosFullScreen;

  @override
  void initState() {
    super.initState();
    _router = createRouter(
      initialLocation: widget.initialLocation,
      auth: () => ref.read(authControllerProvider),
      refresh: _authChanges,
      menuPopups: _menuPopups,
    );
    _observesMacosWindow = defaultTargetPlatform == TargetPlatform.macOS;
    if (_observesMacosWindow) {
      _macosWindow.setMethodCallHandler((call) async {
        if (call.arguments case final bool fullScreen
            when mounted && call.method == 'fullScreenChanged') {
          setState(() => _macosFullScreen = fullScreen);
        }
        return null;
      });
      unawaited(_readMacosFullScreen());
    }
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
    unawaited(Future.microtask(_start));
  }

  StreamSubscription<Uri>? _links;

  /// Prvo sačuvana sesija, pa tek onda linkovi iz mejla (i onaj kojim je
  /// aplikacija pokrenuta), da link ne bi naišao na stanje "Starting".
  Future<void> _start() async {
    final auth = ref.read(authControllerProvider.notifier);
    await auth.start();
    if (!mounted) return;
    _links = ref.read(appLinksProvider).listen((uri) {
      unawaited(_bringToFront());
      unawaited(auth.openLink(uri));
    }, onError: (_) {});
  }

  /// macOS ne izbacuje aplikaciju ispred pregledača kad primi link iz mejla
  /// („Otvori Tavli“), pa bi prijava ostala skrivena iza Chrome-a.
  Future<void> _bringToFront() async {
    if (!_observesMacosWindow) return;
    try {
      await _macosWindow.invokeMethod<void>('activate');
    } on MissingPluginException {
      // Testovi bez macOS runnera.
    }
  }

  Future<void> _readMacosFullScreen() async {
    try {
      final fullScreen = await _macosWindow.invokeMethod<bool>('isFullScreen');
      if (mounted && _macosFullScreen == null && fullScreen != null) {
        setState(() => _macosFullScreen = fullScreen);
      }
    } on MissingPluginException {
      // Testovi bez macOS runnera koriste okvir običnog prozora.
    }
  }

  void _onResume() => unawaited(_resumeSync());

  Future<void> _resumeSync() async {
    await ref
        .read(authControllerProvider.notifier)
        .restoreSession(sync: ref.read(syncEngineProvider));
    if (mounted) await ref.read(syncEngineProvider)?.onResume();
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    if (_observesMacosWindow) _macosWindow.setMethodCallHandler(null);
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
    final theme = buildTavliTheme(choice.theme.motif, Brightness.light);
    final darkTheme = buildTavliTheme(choice.theme.motif, Brightness.dark);
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
        builder: _textScaling,
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
      builder: (context, child) =>
          appMenuBar(_router, ref, _menuPopups, _textScaling(context, child)),
      scaffoldMessengerKey: _messenger,
    );
  }

  /// Sporije skalira velike naslove i ostavlja mesto za semafore na macOS-u.
  Widget _textScaling(BuildContext context, Widget? child) {
    final scaled = TavliTextScaling(child: child ?? const SizedBox.shrink());
    return TavliPlatform.of(context) == TavliPlatform.macos
        ? TavliWindowFrame(
            macosFullScreen: _macosFullScreen ?? false,
            child: scaled,
          )
        : scaled;
  }
}

class _Refresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
