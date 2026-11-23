import 'dart:async';

import 'sync_engine.dart';

typedef _TimerFactory = Timer Function(Duration, void Function());

enum SyncSignalScope {
  account('account_sync_signals'),
  household('household_sync_signals');

  const SyncSignalScope(this.table);
  final String table;
}

abstract interface class SyncSignalRemote {
  Future<bool?> householdEligible(String householdId);

  void Function() subscribe({
    required SyncSignalScope scope,
    required String id,
    required void Function(bool) onConnection,
    required void Function() onSignal,
  });
}

/// Schedules work for one verified account and household. A new account scope
/// gets a new instance, so callbacks from the old scope cannot schedule work.
class RealtimeSync {
  RealtimeSync({
    required this.remote,
    required this.userId,
    required this.householdId,
    required this.refreshMembership,
    required this.pull,
    this.fallbackEvery = const Duration(minutes: 15),
    Timer Function(Duration, void Function())? timer,
    DateTime Function()? clock,
  }) : _timer = timer ?? Timer.new,
       _clock = clock ?? DateTime.now;

  final SyncSignalRemote remote;
  final String userId;
  final String householdId;
  final Future<void> Function() refreshMembership;
  final Future<PullOutcome> Function() pull;
  final Duration fallbackEvery;
  final _TimerFactory _timer;
  final DateTime Function() _clock;

  void Function()? _closeAccount;
  void Function()? _closeHousehold;
  Timer? _fallback;
  Timer? _batch;
  Timer? _retry;
  var _retryStep = 0;
  DateTime? _firstSignal;
  bool? _eligible;
  var _householdGeneration = 0;
  var _accountReady = false;
  var _householdReady = false;
  var _foreground = false;
  var _pending = false;
  var _membership = false;
  var _running = false;
  var _disposed = false;

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _fallback?.cancel();
      _fallback = null;
      _pending |= _batch != null;
      _clearBatch();
      _cancelRetry();
      return;
    }
    _closeAccount ??= remote.subscribe(
      scope: SyncSignalScope.account,
      id: userId,
      onConnection: (ready) {
        if (_disposed) return;
        _accountReady = ready;
        if (ready) _request(membership: true);
        _updateFallback();
      },
      onSignal: () => _request(membership: true),
    );
    _updateFallback();
    unawaited(_drain());
  }

  void _configureHousehold(bool eligible) {
    _eligible = eligible;
    if (!eligible) {
      ++_householdGeneration;
      _closeHousehold?.call();
      _closeHousehold = null;
      _householdReady = false;
      return;
    }
    if (_closeHousehold != null) return;
    final generation = ++_householdGeneration;
    _closeHousehold = remote.subscribe(
      scope: SyncSignalScope.household,
      id: householdId,
      onConnection: (ready) {
        if (_disposed || generation != _householdGeneration) return;
        _householdReady = ready;
        if (ready) _request(membership: true);
        _updateFallback();
      },
      onSignal: () {
        if (!_disposed && generation == _householdGeneration) _batchSignal();
      },
    );
  }

  void _batchSignal() {
    if (!_foreground) {
      _pending = true;
      return;
    }
    final now = _clock();
    final deadline = (_firstSignal ??= now).add(const Duration(seconds: 1));
    final remaining = deadline.difference(now);
    const quiet = Duration(milliseconds: 250);
    _batch?.cancel();
    _batch = _timer(remaining < quiet ? remaining : quiet, () {
      _clearBatch();
      _request();
    });
  }

  void _clearBatch() {
    _batch?.cancel();
    _batch = null;
    _firstSignal = null;
  }

  void _updateFallback() {
    final unhealthy =
        !_accountReady || _eligible == null || (_eligible! && !_householdReady);
    if (!_foreground || _disposed || !unhealthy) {
      _fallback?.cancel();
      _fallback = null;
      return;
    }
    _fallback ??= _timer(fallbackEvery, () {
      _fallback = null;
      _request(membership: true);
      _updateFallback();
    });
  }

  void _request({bool membership = false}) {
    if (_disposed) return;
    _pending = true;
    _membership |= membership;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_running || _disposed || !_foreground) return;
    _running = true;
    try {
      while (_pending &&
          _foreground &&
          !_disposed &&
          (_retry == null || _membership)) {
        final checkMembership = _membership;
        _pending = _membership = false;
        if (checkMembership) {
          try {
            await refreshMembership();
            if (_disposed) return;
            final eligible = await remote.householdEligible(householdId);
            if (_disposed) return;
            if (eligible == null) {
              _configureHousehold(false);
              _eligible = null;
              _cancelRetry();
              _retryStep = 0;
              continue;
            }
            _configureHousehold(eligible);
          } on Exception {
            if (_disposed) return;
            // A failed membership check must not drop the scheduled work:
            // keep it pending, retry with backoff (contracts/signals.md) and
            // leave the fallback armed. `break` waits for the retry timer.
            _eligible = null;
            _pending = _membership = true;
            if (_foreground) _scheduleRetry();
            break;
          }
        }
        if (_eligible == null) continue;
        if (!_foreground || _retry != null) {
          _pending = true;
          continue;
        }
        final outcome = await pull();
        if (_disposed) return;
        if (outcome == PullOutcome.retryableFailure) {
          _pending = true;
          if (_foreground) _scheduleRetry();
        } else {
          _retryStep = 0;
        }
      }
    } finally {
      _running = false;
      _updateFallback();
    }
  }

  void _scheduleRetry() {
    if (_retry != null) return;
    final delay = SyncEngine.backoff[_retryStep];
    if (_retryStep < SyncEngine.backoff.length - 1) _retryStep++;
    _retry = _timer(delay, () {
      _retry = null;
      unawaited(_drain());
    });
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void dispose() {
    _disposed = true;
    _clearBatch();
    _cancelRetry();
    _fallback?.cancel();
    _closeAccount?.call();
    _closeHousehold?.call();
  }
}
