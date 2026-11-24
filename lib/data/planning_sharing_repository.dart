import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../sync/sync_remote.dart';

/// Owner consent for using structured tastes and favorites in shared plans.
class PlanningSharing {
  const PlanningSharing({required this.preferences, required this.revision});

  final bool preferences;
  final int revision;

  static const initial = PlanningSharing(preferences: false, revision: 0);
}

class PlanningSharingConflict implements Exception {
  const PlanningSharingConflict();
}

/// Consent changes are online and revision-checked. The last server response
/// is the effective value; a stale revision tells the caller to reload.
abstract interface class PlanningSharingRepository {
  Future<PlanningSharing> getSharing();
  Future<PlanningSharing> setPreferences(
    bool enabled, {
    required int expectedRevision,
  });
}

class SupabasePlanningSharingRepository implements PlanningSharingRepository {
  SupabasePlanningSharingRepository(this._client, {required this._userId});

  final SupabaseClient _client;
  final String _userId;

  @override
  Future<PlanningSharing> getSharing() => _request(() async {
    final row = await _client.rest
        .from('user_planning_sharing')
        .select('preferences, revision')
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? PlanningSharing.initial : _parse(row);
  });

  @override
  Future<PlanningSharing> setPreferences(
    bool enabled, {
    required int expectedRevision,
  }) => _request(() async {
    final row = await _client.rest
        .rpc<List<Map<String, Object?>>>(
          'set_planning_preferences_sharing',
          params: {'expected_revision': expectedRevision, 'enabled': enabled},
        )
        .single();
    return _parse(row);
  });

  Future<PlanningSharing> _request(
    Future<PlanningSharing> Function() action,
  ) async {
    _requireOwner();
    try {
      final result = await action();
      _requireOwner();
      return result;
    } on PostgrestException catch (error) {
      if (error.code == 'P0001') throw const PlanningSharingConflict();
      throw classifySyncError(error.code ?? '500');
    } on SocketException {
      throw const TransientSyncError('offline');
    } on TimeoutException {
      throw const TransientSyncError('timeout');
    } on http.ClientException {
      throw const TransientSyncError('offline');
    }
  }

  void _requireOwner() {
    if (_client.auth.currentUser?.id != _userId) {
      throw StateError('Saglasnost je dostupna samo aktivnom nalogu.');
    }
  }

  static PlanningSharing _parse(Map<String, Object?> row) {
    final preferences = row['preferences'];
    final revision = row['revision'];
    if (preferences is! bool || revision is! int || revision < 1) {
      throw const FormatException('Saglasnost nije ispravna.');
    }
    return PlanningSharing(preferences: preferences, revision: revision);
  }
}
