import 'dart:async';

import 'package:drift/drift.dart';

import '../account/auth_controller.dart';
import '../data/database.dart';
import 'synced_writer.dart';
import 'uploader.dart';

/// Stanje čuvanja u nalogu (FR-018), prikazano u "Profilu".
sealed class SyncStatus {
  const SyncStatus();
}

class AllSaved extends SyncStatus {
  const AllSaved();
}

class Sending extends SyncStatus {
  const Sending();
}

class Waiting extends SyncStatus {
  const Waiting(this.count);

  final int count;
}

/// Neke izmene je server trajno odbio (ima prednost u prikazu).
class Rejected extends SyncStatus {
  const Rejected(this.count);

  final int count;
}

/// Duži posao posle prijave: prebacivanje starih podataka, preuzimanje.
enum SyncPhase { moving, downloading }

typedef TimerFactory = Timer Function(Duration, void Function());

/// Raspored slanja i preuzimanja za jedan prijavljen nalog (research R13).
/// Slanje: posle prijave, pokretanja, povratka u aplikaciju i svake lokalne
/// izmene (1 s pauze), a bez mreže ponovo posle 5 s, 10 s, pa na 30 s.
class SyncEngine {
  SyncEngine({
    required this._db,
    required this._scope,
    required this._uploader,
    this.onUnauthorized,
    TimerFactory? timer,
    this.debounce = const Duration(seconds: 1),
  }) : _timer = timer ?? Timer.new;

  final AppDatabase _db;
  final AccountScope _scope;
  final Uploader _uploader;
  final TimerFactory _timer;
  final Duration debounce;

  /// Sesija je odbijena i posle obnove: nazad na prijavu.
  final Future<void> Function()? onUnauthorized;

  static const backoff = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final _status = StreamController<SyncStatus>.broadcast();
  final _phase = StreamController<SyncPhase?>.broadcast();
  SyncStatus _current = const AllSaved();
  SyncPhase? _currentPhase;

  Timer? _debounceTimer;
  Timer? _retryTimer;
  var _failures = 0;
  var _running = false;
  var _again = false;
  var _stopped = false;
  Future<void>? _inFlight;

  SyncStatus get status => _current;
  SyncPhase? get phase => _currentPhase;

  /// Trenutno stanje pa promene.
  Stream<SyncStatus> watchStatus() async* {
    yield _current;
    yield* _status.stream;
  }

  Stream<SyncPhase?> watchPhase() async* {
    yield _currentPhase;
    yield* _phase.stream;
  }

  /// Posle prijave ili pokretanja aplikacije.
  Future<void> onStart() async {
    // Slanje prekinuto gašenjem aplikacije: te izmene opet čekaju.
    await (_db.update(_db.syncOutbox)..where(
          (t) =>
              t.accountId.equals(_scope.userId) &
              t.state.equals(OutboxState.sending),
        ))
        .write(const SyncOutboxCompanion(state: Value(OutboxState.pending)));
    await push();
  }

  /// Povratak u aplikaciju.
  Future<void> onResume() => push();

  /// Zona u kojoj je engine napravljen. [kick] se zove iz drift
  /// transakcije, a tajmeri i upiti ne smeju da ostanu u njenoj zoni.
  final Zone _zone = Zone.current;

  /// Posle lokalne izmene: šalje se posle kratke pauze (spaja više izmena).
  void kick() => _zone.run(() {
    if (_stopped) return;
    _debounceTimer?.cancel();
    _debounceTimer = _timer(debounce, () => unawaited(push()));
    unawaited(refreshStatus());
  });

  /// Šalje sve što čeka. Ako slanje već traje, ponavlja se posle njega.
  Future<void> push() {
    if (_stopped) return Future.value();
    if (_running) {
      _again = true;
      return _inFlight ?? Future.value();
    }
    return _inFlight = _push();
  }

  Future<void> _push() async {
    _running = true;
    _retryTimer?.cancel();
    try {
      do {
        _again = false;
        if (await _waitingCount() > 0) _emit(const Sending());
        final result = await _uploader.run();
        if (_stopped) return;
        if (result.unauthorized) {
          await onUnauthorized?.call();
          return;
        }
        if (result.offline) {
          _scheduleRetry();
          return;
        }
        _failures = 0;
        if (await _hasPostponedPhotos()) _scheduleRetry();
      } while (_again && !_stopped);
    } finally {
      _running = false;
      if (!_stopped) await refreshStatus();
    }
  }

  void _scheduleRetry() {
    final wait = backoff[_failures.clamp(0, backoff.length - 1)];
    _failures++;
    _retryTimer?.cancel();
    _retryTimer = _timer(wait, () => unawaited(push()));
  }

  Future<int> _count(String state) async {
    final n = _db.syncOutbox.seq.count();
    final q = _db.selectOnly(_db.syncOutbox)
      ..addColumns([n])
      ..where(
        _db.syncOutbox.accountId.equals(_scope.userId) &
            _db.syncOutbox.state.equals(state),
      );
    return (await q.getSingle()).read(n) ?? 0;
  }

  Future<int> _waitingCount() async =>
      await _count(OutboxState.pending) + await _count(OutboxState.sending);

  Future<bool> _hasPostponedPhotos() async =>
      await (_db.select(_db.syncOutbox)
            ..where(
              (t) =>
                  t.accountId.equals(_scope.userId) &
                  t.state.equals(OutboxState.pending) &
                  t.nextAttemptAt.isNotNull(),
            )
            ..limit(1))
          .getSingleOrNull() !=
      null;

  /// Računa stanje iz reda izmena.
  Future<void> refreshStatus() async {
    if (_stopped) return;
    final rejected = await _count(OutboxState.rejected);
    final waiting = await _waitingCount();
    _emit(
      rejected > 0
          ? Rejected(rejected)
          : _running && waiting > 0
          ? const Sending()
          : waiting > 0
          ? Waiting(waiting)
          : const AllSaved(),
    );
  }

  void _emit(SyncStatus s) {
    if (_stopped) return;
    _current = s;
    _status.add(s);
  }

  void setPhase(SyncPhase? p) {
    if (_stopped) return;
    _currentPhase = p;
    _phase.add(p);
  }

  /// Odjava ili promena naloga: bez daljeg slanja.
  void stop() {
    _stopped = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    unawaited(_status.close());
    unawaited(_phase.close());
  }
}
