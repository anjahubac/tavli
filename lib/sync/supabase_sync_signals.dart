import 'dart:async';

import 'package:supabase/supabase.dart';

import 'realtime_sync.dart';

class SupabaseSyncSignals implements SyncSignalRemote {
  const SupabaseSyncSignals(this._client);

  final SupabaseClient _client;

  @override
  Future<bool?> householdEligible(String householdId) => _client.rpc<bool?>(
    'household_realtime_eligible',
    params: {'expected_household': householdId},
  );

  @override
  void Function() subscribe({
    required SyncSignalScope scope,
    required String id,
    required void Function(bool) onConnection,
    required void Function() onSignal,
  }) {
    var active = true;
    var ready = false;
    final channel = _client.channel('tavli:sync:${scope.name}:$id');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: scope.table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (payload) {
            final revision = payload.newRecord['revision'];
            if (active &&
                payload.newRecord['id'] == id &&
                revision is int &&
                revision > 0) {
              onSignal();
            }
          },
        )
        .onSystemEvents((payload) {
          // The Phoenix join is acknowledged before replication is ready.
          if (active &&
              !ready &&
              payload is Map<String, dynamic> &&
              payload['extension'] == 'postgres_changes' &&
              payload['status'] == 'ok') {
            ready = true;
            onConnection(true);
          }
        })
        .subscribe((status, _) {
          if (active && status != RealtimeSubscribeStatus.subscribed) {
            ready = false;
            onConnection(false);
          }
        });
    return () {
      if (!active) return;
      active = false;
      unawaited(_client.removeChannel(channel).then<void>((_) {}));
    };
  }
}
