import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/animations/egg_timer.dart';
import 'recipe_providers.dart';

/// Štoperica u bloku tajmera (linijska ikonica, kao u pregledu).
const _timerIcon = TavliIconData('timer', [
  'circle 12 13 8',
  'M12 9v4l2.5 2.5',
  'M9 2h6',
]);

enum CookingTimerPhase { running, paused, finished }

/// Jedan tajmer u režimu kuvanja, vezan za korak u kome je pokrenut.
@immutable
class CookingTimerState {
  const CookingTimerState({
    required this.phase,
    required this.step,
    required this.total,
    this.endAt,
    this.left = Duration.zero,
  });

  final CookingTimerPhase phase;
  final int step;
  final Duration total;

  /// Kad tajmer ističe (samo dok radi).
  final DateTime? endAt;

  /// Preostalo dok je pauziran; nula kad je isteklo.
  final Duration left;

  Duration remaining(DateTime now) {
    if (phase != CookingTimerPhase.running) return left;
    final d = endAt!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Zvuk (i vibracija na telefonu) kad vreme istekne.
abstract interface class CookingTimerAlert {
  Future<void> play();
}

/// Sistemski zvuk, tri puta; na telefonu uz kratku vibraciju. Na računaru
/// samo zvuk (Anja, 23.11.2026).
class SystemCookingTimerAlert implements CookingTimerAlert {
  const SystemCookingTimerAlert();

  static bool get _phone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> play() async {
    try {
      for (var i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        if (_phone) await HapticFeedback.vibrate();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    } on Exception {
      if (kDebugMode) debugPrint('Tajmer: zvuk nije uspeo.');
    }
  }
}

final cookingTimerAlertProvider = Provider<CookingTimerAlert>(
  (ref) => const SystemCookingTimerAlert(),
);

final cookingTimerProvider =
    NotifierProvider.autoDispose<CookingTimer, CookingTimerState?>(
      CookingTimer.new,
    );

class CookingTimer extends Notifier<CookingTimerState?> {
  Timer? _timer;

  DateTime _now() => ref.read(clockProvider)();

  @override
  CookingTimerState? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Pokreće tajmer za korak; postojeći tajmer se zamenjuje.
  void start(int step, Duration total) => _run(step, total, total);

  void pause() {
    final s = state;
    if (s == null || s.phase != CookingTimerPhase.running) return;
    _timer?.cancel();
    state = CookingTimerState(
      phase: CookingTimerPhase.paused,
      step: s.step,
      total: s.total,
      left: s.remaining(_now()),
    );
  }

  void resume() {
    final s = state;
    if (s == null || s.phase != CookingTimerPhase.paused) return;
    _run(s.step, s.total, s.left);
  }

  /// +1 min; kad je vreme isteklo, kreće novi minut.
  void addMinute() {
    final s = state;
    if (s == null) return;
    const minute = Duration(minutes: 1);
    switch (s.phase) {
      case CookingTimerPhase.running:
        _run(s.step, s.total + minute, s.remaining(_now()) + minute);
      case CookingTimerPhase.paused:
        state = CookingTimerState(
          phase: CookingTimerPhase.paused,
          step: s.step,
          total: s.total + minute,
          left: s.left + minute,
        );
      case CookingTimerPhase.finished:
        _run(s.step, minute, minute);
    }
  }

  /// Otkaži (ili zatvori poruku kad je isteklo).
  void stop() {
    _timer?.cancel();
    state = null;
  }

  void _run(int step, Duration total, Duration left) {
    _timer?.cancel();
    state = CookingTimerState(
      phase: CookingTimerPhase.running,
      step: step,
      total: total,
      endAt: _now().add(left),
    );
    _timer = Timer(left, _finish);
  }

  void _finish() {
    final s = state;
    if (s == null || s.phase != CookingTimerPhase.running) return;
    state = CookingTimerState(
      phase: CookingTimerPhase.finished,
      step: s.step,
      total: s.total,
    );
    unawaited(ref.read(cookingTimerAlertProvider).play());
  }
}

/// Ponovo crta svake sekunde sa trenutnim vremenom.
class _TimerClock extends ConsumerStatefulWidget {
  const _TimerClock({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  ConsumerState<_TimerClock> createState() => _TimerClockState();
}

class _TimerClockState extends ConsumerState<_TimerClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, ref.read(clockProvider)());
}

/// Blok tajmera ispod teksta koraka: „Pokreni tajmer“ ako korak pominje
/// vreme, a kad tajmer radi u ovom koraku, jaje u loncu sa prstenom.
class CookingTimerBlock extends ConsumerWidget {
  const CookingTimerBlock({
    super.key,
    required this.step,
    required this.duration,
  });

  final int step;

  /// Vreme koje korak pominje (null: korak nema vreme).
  final Duration? duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(cookingTimerProvider);
    final notifier = ref.read(cookingTimerProvider.notifier);
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    if (timer != null && timer.step == step) {
      final finished = timer.phase == CookingTimerPhase.finished;
      final paused = timer.phase == CookingTimerPhase.paused;
      return Padding(
        padding: const EdgeInsets.only(top: TavliSpacing.medium),
        child: TavliCard(
          child: Column(
            children: [
              _TimerClock(
                builder: (context, now) => EggTimer(
                  size: 150,
                  running: timer.phase == CookingTimerPhase.running,
                  remaining: timer.remaining(now),
                  total: timer.total,
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  finished
                      ? 'Vreme je isteklo'
                      : paused
                      ? 'Pauzirano'
                      : 'Preostalo',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: finished ? c.primary : c.onSurfaceVariant,
                    fontWeight: finished ? FontWeight.w700 : null,
                  ),
                ),
              ),
              const SizedBox(height: TavliSpacing.medium),
              TavliButtonRow(
                expand: true,
                children: [
                  if (!finished)
                    TavliButton.secondary(
                      label: paused ? 'Nastavi' : 'Pauziraj',
                      onPressed: paused ? notifier.resume : notifier.pause,
                    ),
                  TavliButton.secondary(
                    label: '+1 min',
                    onPressed: notifier.addMinute,
                  ),
                  TavliButton.secondary(
                    label: finished ? 'Zatvori' : 'Otkaži',
                    onPressed: notifier.stop,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final d = duration;
    if (d == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TavliSpacing.medium),
      child: TavliCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TavliIcon(_timerIcon, size: 28, color: c.onSurfaceVariant),
                const SizedBox(width: TavliSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tajmer za ovaj korak',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timer == null
                            ? 'Korak pominje vreme.'
                            : 'Pokretanje zamenjuje tajmer iz drugog koraka.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TavliSpacing.medium),
            TavliButtonRow(
              expand: true,
              children: [
                TavliButton.primary(
                  label: 'Pokreni tajmer · ${EggTimer.format(d)}',
                  onPressed: () => notifier.start(step, d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Traka na vrhu kad tajmer radi (ili je istekao) u drugom koraku; dodir
/// vraća na korak tajmera.
class CookingTimerStrip extends ConsumerWidget {
  const CookingTimerStrip({
    super.key,
    required this.step,
    required this.onOpen,
  });

  final int step;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(cookingTimerProvider);
    if (timer == null || timer.step == step) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final finished = timer.phase == CookingTimerPhase.finished;
    return Material(
      color: finished ? c.primaryContainer : c.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TavliSpacing.large,
            vertical: TavliSpacing.small,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onOpen(timer.step),
                  child: _TimerClock(
                    builder: (context, now) {
                      final left = timer.remaining(now);
                      final label = finished
                          ? 'Vreme je isteklo'
                          : timer.phase == CookingTimerPhase.paused
                          ? 'Tajmer pauziran · ${EggTimer.format(left)}'
                          : 'Tajmer · ${EggTimer.format(left)}';
                      return Row(
                        children: [
                          EggTimer(
                            size: 44,
                            showTime: false,
                            running: timer.phase == CookingTimerPhase.running,
                            remaining: left,
                            total: timer.total,
                          ),
                          const SizedBox(width: TavliSpacing.small),
                          Expanded(
                            child: Semantics(
                              liveRegion: finished,
                              child: Text(
                                '$label · korak ${timer.step + 1}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (finished)
                TavliButton.text(
                  label: 'Zatvori',
                  onPressed: ref.read(cookingTimerProvider.notifier).stop,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
