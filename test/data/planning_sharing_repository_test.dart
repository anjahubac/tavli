import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tavli/account/supabase_client.dart';
import 'package:tavli/account/supabase_config.dart';
import 'package:tavli/data/planning_sharing_repository.dart';

import '../helpers/fake_secret_storage.dart';
import '../helpers/fake_supabase.dart';

void main() {
  test('consent starts off and writes only through the revision RPC', () async {
    final requests = <http.Request>[];
    late http.Response Function(http.Request) respond;
    final client = createSupabaseClient(
      const SupabaseConfig(url: fakeUrl, anonKey: fakeAnonKey),
      secrets: MapSecretStorage(),
      httpClient: mockHttp((request) {
        requests.add(request);
        return respond(request);
      }),
    );
    addTearDown(client.dispose);
    respond = (_) => throw StateError('Neočekivan zahtev za prijavu.');
    await client.auth.recoverSession(jsonEncode(sessionBody()));
    final repo = SupabasePlanningSharingRepository(client, userId: 'u1');

    respond = (_) => jsonResponse(<Object>[]);
    final initial = await repo.getSharing();
    expect(initial.preferences, isFalse);
    expect(initial.revision, 0);
    expect(requests.single.url.queryParameters['user_id'], 'eq.u1');

    respond = (_) => jsonResponse({'preferences': true, 'revision': 1});
    final enabled = await repo.setPreferences(true, expectedRevision: 0);
    expect(enabled.preferences, isTrue);
    expect(enabled.revision, 1);
    expect(
      requests.last.url.path,
      '/rest/v1/rpc/set_planning_preferences_sharing',
    );
    expect(jsonDecode(requests.last.body), {
      'expected_revision': 0,
      'enabled': true,
    });

    respond = (_) => jsonResponse({'code': 'P0001', 'message': 'stale'}, 400);
    await expectLater(
      repo.setPreferences(false, expectedRevision: 0),
      throwsA(isA<PlanningSharingConflict>()),
    );
    final otherAccount = SupabasePlanningSharingRepository(
      client,
      userId: 'other',
    );
    await expectLater(otherAccount.getSharing(), throwsStateError);
    expect(requests, hasLength(3));
  });
}
