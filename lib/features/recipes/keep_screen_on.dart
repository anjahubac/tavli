import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/database.dart';
import '../../providers.dart';

/// Drži ekran upaljenim (sistem ga inače gasi posle par minuta).
abstract interface class ScreenWakeLock {
  Future<void> enable();
  Future<void> disable();
}

class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  const WakelockPlusScreenWakeLock();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

final screenWakeLockProvider = Provider<ScreenWakeLock>(
  (ref) => const WakelockPlusScreenWakeLock(),
);

/// "Ne gasi ekran" dok je recept otvoren; čuva se u AppSettings.
class KeepScreenOn extends AsyncNotifier<bool> {
  static const settingKey = 'keep_screen_on';

  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(
      db.appSettings,
    )..where((t) => t.key.equals(settingKey))).getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    final db = ref.read(databaseProvider);
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(key: settingKey, value: '$on'),
          mode: InsertMode.insertOrReplace,
        );
  }
}

final keepScreenOnProvider = AsyncNotifierProvider<KeepScreenOn, bool>(
  KeepScreenOn.new,
);

/// Dok je ovaj widget na ekranu i opcija uključena, ekran se ne gasi.
class KeepScreenOnScope extends ConsumerStatefulWidget {
  const KeepScreenOnScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreenOnScope> createState() => _KeepScreenOnScopeState();
}

class _KeepScreenOnScopeState extends ConsumerState<KeepScreenOnScope> {
  late final ScreenWakeLock _lock = ref.read(screenWakeLockProvider);

  /// Šta korisnik traži (opcija uključena).
  bool _wanted = false;

  /// Šta je platforma potvrdila. Razlikuje se od [_wanted] kad zahtev propadne,
  /// pa zatvaranje recepta može da ponovi neuspelo otpuštanje.
  bool _confirmed = false;

  /// Zahtevi idu jedan za drugim da potvrđeno stanje ne bude u trci.
  Future<void> _queue = Future.value();

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      keepScreenOnProvider,
      (_, next) => _apply(next.value ?? false),
      fireImmediately: true,
    );
  }

  void _apply(bool on) {
    if (on == _wanted) return;
    _wanted = on;
    _enqueue(on);
  }

  void _enqueue(bool on) {
    _queue = _queue.then((_) => _run(on));
    unawaited(_queue);
  }

  /// Ako platforma ne podrži zahtev, aplikacija radi dalje.
  Future<void> _run(bool on) async {
    if (on == _confirmed) return;
    try {
      await (on ? _lock.enable() : _lock.disable());
      _confirmed = on;
    } on Exception {
      if (kDebugMode) debugPrint('Ekran: zahtev nije uspeo.');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              on
                  ? 'Sistem nije uspeo da spreči gašenje ekrana. Proveri da li okruženje podržava ovu funkciju.'
                  : 'Nije uspelo isključivanje zadržavanja ekrana. Ekran može ostati uključen dok se recept ne zatvori.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Otpuštanje se pokušava i kad je ranije propalo (_confirmed je i dalje true).
    if (_wanted || _confirmed) {
      _wanted = false;
      _enqueue(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Dugme u traci recepta. Status se vidi u svakom trenutku: uključeno je
/// sunce na obojenoj podlozi („ekran ostaje budan“), isključeno je mesec
/// bez podloge („ekran sme da zaspi“). Promena se animira (sunce izlazi,
/// mesec zalazi), osim kad sistem traži smanjeno kretanje.
class KeepScreenOnButton extends ConsumerWidget {
  const KeepScreenOnButton({super.key});

  static const onIcon = Icons.light_mode;
  static const offIcon = Icons.bedtime_outlined;

  static String tooltipFor({required bool on}) =>
      on ? 'Ne gasi ekran: uključeno' : 'Ne gasi ekran: isključeno';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(keepScreenOnProvider).value ?? false;
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltipFor(on: on),
      isSelected: on,
      style: IconButton.styleFrom(
        backgroundColor: on ? scheme.primaryContainer : Colors.transparent,
        foregroundColor: on
            ? scheme.onPrimaryContainer
            : scheme.onSurfaceVariant,
        animationDuration: TavliMotion.duration(
          context,
          TavliMotion.transition,
        ),
      ),
      icon: AnimatedSwitcher(
        duration: TavliMotion.duration(context, TavliMotion.reveal),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: -0.25, end: 0).animate(animation),
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(on ? onIcon : offIcon, key: ValueKey(on)),
      ),
      onPressed: () async {
        await ref.read(keepScreenOnProvider.notifier).set(!on);
      },
    );
  }
}
