import 'dart:async';

/// Tajmeri koje test pokreće ručno ([fire]), bez čekanja.
class FakeTimers {
  final pending = <FakeTimer>[];

  Timer call(Duration d, void Function() callback) {
    final t = FakeTimer(d, callback, this);
    pending.add(t);
    return t;
  }

  /// Trajanja tajmera koji čekaju.
  List<Duration> get durations => [for (final t in pending) t.duration];

  /// Pokreće sve tajmere koji čekaju (ili samo one sa trajanjem [only]).
  Future<void> fire([Duration? only]) async {
    for (final t in [...pending]) {
      if (only == null || t.duration == only) t.fire();
    }
    await pumpQueue();
  }
}

class FakeTimer implements Timer {
  FakeTimer(this.duration, this._callback, this._owner);

  final Duration duration;
  final void Function() _callback;
  final FakeTimers _owner;
  var _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _owner.pending.remove(this);
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _owner.pending.remove(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Pušta da se završe svi započeti asinhroni poslovi.
Future<void> pumpQueue() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
