import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _held = false;

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
    if (on == _held) return;
    _held = on;
    unawaited(_call(on ? _lock.enable : _lock.disable));
  }

  /// Ako platforma ne podrži zahtev, aplikacija radi dalje.
  static Future<void> _call(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Ekran: zahtev nije uspeo ($e)');
    }
  }

  @override
  void dispose() {
    if (_held) unawaited(_call(_lock.disable));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Dugme u traci recepta.
class KeepScreenOnButton extends ConsumerWidget {
  const KeepScreenOnButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(keepScreenOnProvider).value ?? false;
    return IconButton(
      tooltip: 'Ne gasi ekran',
      isSelected: on,
      icon: const Icon(Icons.light_mode_outlined),
      selectedIcon: const Icon(Icons.light_mode),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(keepScreenOnProvider.notifier).set(!on);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                on
                    ? 'Ekran se gasi kao i obično.'
                    : 'Ekran se neće gasiti dok je recept otvoren.',
              ),
            ),
          );
      },
    );
  }
}
