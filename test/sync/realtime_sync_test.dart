import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/sync/realtime_sync.dart';
import 'package:tavli/sync/sync_engine.dart';

import '../helpers/fake_timers.dart';

const quiet = Duration(milliseconds: 250);
const fallback = Duration(minutes: 15);

void main() {
  late _Remote remote;
  late FakeTimers timers;
  late RealtimeSync sync;
  late DateTime now;
  late List<String> work;
  Completer<void>? blockedPull;
  late int transientFailures;

  setUp(() {
    remote = _Remote();
    timers = FakeTimers();
    now = DateTime.utc(2026, 11, 23);
    work = [];
    blockedPull = null;
    transientFailures = 0;
    sync = RealtimeSync(
      remote: remote,
      userId: 'account',
      householdId: 'home',
      refreshMembership: () async => work.add('membership'),
      pull: () async {
        work.add('pull');
        final blocked = blockedPull;
        blockedPull = null;
        await blocked?.future;
        if (transientFailures > 0) {
          transientFailures--;
          return PullOutcome.retryableFailure;
        }
        return PullOutcome.settled;
      },
      timer: timers.call,
      clock: () => now,
    );
    sync.setForeground(true);
  });

  tearDown(() => sync.dispose());

  Future<void> connectBoth() async {
    remote.eligible = true;
    remote.account.connection(true);
    await pumpQueue();
    remote.household.connection(true);
    await pumpQueue();
    work.clear();
  }

  test(
    'legacy solo eligibility subscribes and loss of membership detaches',
    () async {
      remote.account.connection(true);
      await pumpQueue();
      expect(remote.subscriptions, hasLength(2));
      expect(timers.durations, [fallback]);
      expect(work, ['membership', 'pull']);

      remote.eligible = true;
      remote.account.signal();
      await pumpQueue();
      final old = remote.household;
      expect(old.id, 'home');

      remote.eligible = null;
      remote.account.signal();
      await pumpQueue();
      expect(old.closed, isTrue);
      work.clear();
      old.signal();
      old.connection(true);
      await timers.fire(quiet);
      expect(work, isEmpty);
    },
  );

  test('healthy channels catch up when a signal is silently missed', () async {
    await connectBoth();
    await timers.fire(fallback);
    expect(work, ['membership', 'pull']);
    expect(timers.durations, [fallback]);
  });

  test('healthy channels retry a failed pull with capped backoff', () async {
    await connectBoth();
    transientFailures = 4;
    remote.household.signal();
    await timers.fire(quiet);
    expect(work, ['pull']);

    remote.household.signal();
    await timers.fire(quiet);
    expect(work, ['pull']);

    final delays = [...SyncEngine.backoff, SyncEngine.backoff.last];
    for (final (index, delay) in delays.indexed) {
      expect(timers.durations, unorderedEquals([fallback, delay]));
      await timers.fire(delay);
      expect(work, List.filled(index + 2, 'pull'));
    }
    expect(timers.durations, [fallback]);

    transientFailures = 1;
    remote.household.signal();
    await timers.fire(quiet);
    expect(
      timers.durations,
      unorderedEquals([fallback, SyncEngine.backoff.first]),
    );
  });

  test(
    'background pauses retries, resume catches up, and disposal cancels',
    () async {
      await connectBoth();
      transientFailures = 2;
      remote.household.signal();
      await timers.fire(quiet);

      sync.setForeground(false);
      expect(timers.pending, isEmpty);
      await timers.fire();
      expect(work, ['pull']);

      sync.setForeground(true);
      await pumpQueue();
      expect(work, ['pull', 'pull']);
      expect(
        timers.durations,
        unorderedEquals([fallback, SyncEngine.backoff[1]]),
      );

      sync.dispose();
      expect(timers.pending, isEmpty);
      await timers.fire();
      expect(work, ['pull', 'pull']);
    },
  );

  test(
    'a failed membership check is retried with backoff, not 15 min',
    () async {
      remote.eligible = true;
      remote.failEligible = 2;
      remote.account.connection(true);
      await pumpQueue();
      expect(work, ['membership']);
      expect(remote.subscriptions, hasLength(1));
      expect(timers.durations, contains(SyncEngine.backoff.first));

      remote.account.signal();
      remote.account.connection(true);
      await pumpQueue();
      expect(work, ['membership']);

      await timers.fire(SyncEngine.backoff.first);
      expect(work, ['membership', 'membership']);
      expect(remote.subscriptions, hasLength(1));
      expect(timers.durations, contains(SyncEngine.backoff[1]));

      await timers.fire(SyncEngine.backoff[1]);
      expect(work, ['membership', 'membership', 'membership', 'pull']);
      expect(remote.subscriptions, hasLength(2));
      expect(remote.household.id, 'home');
    },
  );

  test('an exception from an in-flight pull preserves the retry', () async {
    await connectBoth();
    final first = blockedPull = Completer<void>();
    remote.household.signal();
    await timers.fire(quiet);
    first.completeError(Exception('cache unavailable'));
    await pumpQueue();
    expect(
      timers.durations,
      unorderedEquals([fallback, SyncEngine.backoff.first]),
    );
    await timers.fire(SyncEngine.backoff.first);
    expect(work, ['pull', 'pull']);
    expect(timers.durations, [fallback]);
  });

  test('membership changes are checked during pull backoff', () async {
    await connectBoth();
    transientFailures = 1;
    remote.household.signal();
    await timers.fire(quiet);
    expect(
      timers.durations,
      unorderedEquals([fallback, SyncEngine.backoff.first]),
    );

    remote.eligible = null;
    remote.account.signal();
    await pumpQueue();
    expect(work, ['pull', 'membership']);
    expect(remote.household.closed, isTrue);
    expect(timers.durations, [fallback]);
  });

  test('continuous signals wait at most one second before one pull', () async {
    await connectBoth();
    remote.household.signal();
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(milliseconds: 180));
      remote.household.signal();
    }
    expect(
      timers.durations,
      unorderedEquals([fallback, const Duration(milliseconds: 100)]),
    );
    await timers.fire(const Duration(milliseconds: 100));
    expect(work, ['pull']);
  });

  test('a signal during pull schedules one serial follow-up', () async {
    await connectBoth();
    final first = blockedPull = Completer<void>();
    remote.household.signal();
    await timers.fire(quiet);
    remote.household.signal();
    remote.household.signal();
    await timers.fire(quiet);
    expect(work, ['pull']);
    first.complete();
    await pumpQueue();
    expect(work, ['pull', 'pull']);
  });

  test(
    'reconnect catches up and an overlapping fallback stays serial',
    () async {
      await connectBoth();
      remote.household.connection(false);
      expect(timers.durations, [fallback]);
      final first = blockedPull = Completer<void>();
      await timers.fire(fallback);
      expect(work, ['membership', 'pull']);
      remote.household.connection(true);
      await pumpQueue();
      expect(work, ['membership', 'pull']);
      expect(timers.durations, [fallback]);
      first.complete();
      await pumpQueue();
      expect(work, ['membership', 'pull', 'membership', 'pull']);
    },
  );

  test(
    'fallback runs while foregrounded and stops on background or disposal',
    () async {
      expect(timers.durations, [fallback]);
      await timers.fire(fallback);
      expect(work, ['membership', 'pull']);
      expect(timers.durations, [fallback]);
      sync.setForeground(false);
      expect(timers.pending, isEmpty);
      await timers.fire();
      expect(work, ['membership', 'pull']);
      sync.setForeground(true);
      expect(timers.durations, [fallback]);
      sync.dispose();
      expect(remote.account.closed, isTrue);
      expect(timers.pending, isEmpty);
      remote.account.signal();
      await pumpQueue();
      expect(work, ['membership', 'pull']);
    },
  );

  test(
    'changed household blocks old scope pulls even with queued signals',
    () async {
      await connectBoth();
      remote.eligible = null;
      remote.account.signal();
      remote.household.signal();
      await pumpQueue();
      await timers.fire(quiet);
      expect(remote.household.closed, isTrue);
      expect(work, ['membership']);
      expect(timers.durations, [fallback]);
    },
  );
}

class _Remote implements SyncSignalRemote {
  bool? eligible = false;
  int failEligible = 0;
  final subscriptions = <_Subscription>[];

  _Subscription get account => subscriptions.first;
  _Subscription get household => subscriptions.last;

  @override
  Future<bool?> householdEligible(String householdId) async {
    if (failEligible > 0) {
      failEligible--;
      throw TimeoutException('membership check');
    }
    return eligible;
  }

  @override
  void Function() subscribe({
    required SyncSignalScope scope,
    required String id,
    required void Function(bool) onConnection,
    required void Function() onSignal,
  }) {
    final subscription = _Subscription(id, onConnection, onSignal);
    subscriptions.add(subscription);
    return () => subscription.closed = true;
  }
}

class _Subscription {
  _Subscription(this.id, this.connection, this.signal);

  final String id;
  final void Function(bool) connection;
  final void Function() signal;
  bool closed = false;
}
