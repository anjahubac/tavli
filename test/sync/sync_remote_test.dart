import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:tavli/account/supabase_client.dart';
import 'package:tavli/account/supabase_config.dart';
import 'package:tavli/sync/sync_remote.dart';

import '../helpers/fake_supabase.dart';

void main() {
  late SupabaseClient client;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;

  setUp(() async {
    requests = [];
    handler = (_) => jsonResponse(<Object>[]);
    client = createSupabaseClient(
      const SupabaseConfig(url: fakeUrl, anonKey: fakeAnonKey),
      httpClient: mockHttp((r) {
        requests.add(r);
        return handler(r);
      }),
    );
  });
  tearDown(() => client.dispose());

  SupabaseSyncRemote remote() => SupabaseSyncRemote(client);

  test('upsert šalje sve redove odjednom, po id-ju', () async {
    handler = (_) => http.Response('', 201);
    await remote().upsert('recipes', [
      {'id': 'a', 'title': 'Sarma'},
      {'id': 'b', 'title': 'Pasulj'},
    ]);
    final r = requests.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/rest/v1/recipes');
    expect(r.url.queryParameters['on_conflict'], 'id');
    expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
    expect(jsonDecode(r.body), hasLength(2));
  });

  test('profil ukusa: upsert po user_id', () async {
    handler = (_) => http.Response('', 201);
    await remote().upsert('taste_profiles', [
      {'user_id': 'u1', 'profile': <String, Object?>{}},
    ], onConflict: 'user_id');
    expect(requests.single.url.queryParameters['on_conflict'], 'user_id');
  });

  test('brisanje: id=in.(…)', () async {
    handler = (_) => http.Response('', 204);
    await remote().delete('recipes', ['a', 'b']);
    final r = requests.single;
    expect(r.method, 'DELETE');
    expect(r.url.queryParameters['id'], 'in.("a","b")');
  });

  test('ime u profilu', () async {
    handler = (_) => http.Response('', 204);
    await remote().updateProfileName('u1', 'Ana');
    final r = requests.single;
    expect(r.method, 'PATCH');
    expect(r.url.path, '/rest/v1/profiles');
    expect(r.url.queryParameters['id'], 'eq.u1');
    expect(jsonDecode(r.body), {'display_name': 'Ana'});
  });

  test('fetchSince: filter po (updated_at, id) i redosled', () async {
    handler = (_) => jsonResponse([
      {'id': 'a', 'updated_at': '2026-11-01T00:00:00Z'},
    ]);
    const t = '2026-11-01T00:00:00.000001Z';
    final rows = await remote().fetchSince(
      'recipes',
      limit: 500,
      since: t,
      afterId: 'x',
    );
    expect(rows.single['id'], 'a');
    final q = requests.single.url.queryParameters;
    expect(q['or'], '(updated_at.gt."$t",and(updated_at.eq."$t",id.gt."x"))');
    expect(q['order'], 'updated_at.asc.nullslast,id.asc.nullslast');
    expect(q['limit'], '500');

    requests.clear();
    await remote().fetchSince('recipes', limit: 10);
    expect(requests.single.url.queryParameters.containsKey('or'), isFalse);

    requests.clear();
    await remote().fetchSince(
      'deletions',
      limit: 10,
      since: t,
      timeColumn: 'deleted_at',
    );
    expect(requests.single.url.queryParameters['deleted_at'], 'gte.$t');
  });

  group('vrste grešaka', () {
    Future<SyncError> errorFor(FutureOr<http.Response> Function() h) async {
      handler = (_) => h();
      try {
        await remote().upsert('recipes', [
          {'id': 'a'},
        ]);
      } on SyncError catch (e) {
        return e;
      }
      fail('očekivana greška');
    }

    http.Response pg(String code, int status) =>
        jsonResponse({'code': code, 'message': 'sadržaj reda'}, status);

    test('mreža, istek vremena, 5xx i 429 → privremena', () async {
      expect(
        await errorFor(() => throw const SocketException('x')),
        isA<TransientSyncError>(),
      );
      expect(
        await errorFor(() => throw TimeoutException('x')),
        isA<TransientSyncError>(),
      );
      expect(
        await errorFor(() => http.Response('bad gateway', 502)),
        isA<TransientSyncError>(),
      );
      expect(
        await errorFor(() => http.Response('slow down', 429)),
        isA<TransientSyncError>(),
      );
    });

    test('401 i istekao JWT → obnova sesije', () async {
      expect(
        await errorFor(() => pg('PGRST301', 401)),
        isA<UnauthorizedSyncError>(),
      );
      expect(
        await errorFor(() => http.Response('unauthorized', 401)),
        isA<UnauthorizedSyncError>(),
      );
    });

    test('neispravni podaci i prava → trajna, samo kod', () async {
      for (final (code, status) in [
        ('23514', 400),
        ('22P02', 400),
        ('23503', 409),
        ('42501', 403),
      ]) {
        final e = await errorFor(() => pg(code, status));
        expect(e, isA<PermanentSyncError>());
        expect(e.code, code);
        expect(e.toString(), isNot(contains('sadržaj')));
      }
      expect(
        await errorFor(() => http.Response('bad', 422)),
        isA<PermanentSyncError>(),
      );
    });
  });

  group('slike', () {
    test('upload u {domaćinstvo}/{fajl} sa upsert-om', () async {
      handler = (_) => jsonResponse({'Key': 'recipe-photos/h1/a.jpg'});
      await SupabasePhotoRemote(client)
          .upload('h1/a.jpg', Uint8List.fromList([1, 2, 3]));
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/storage/v1/object/recipe-photos/h1/a.jpg');
      expect(r.headers['x-upsert'], 'true');
    });

    test('preuzimanje i brisanje', () async {
      handler = (r) => r.method == 'GET'
          ? http.Response.bytes([7, 8], 200)
          : jsonResponse(<Object>[]);
      final photos = SupabasePhotoRemote(client);
      expect(await photos.download('h1/a.jpg'), [7, 8]);
      await photos.remove(['h1/a.jpg']);
      expect(requests.last.method, 'DELETE');
    });

    test('nema slike → trajna greška; 5xx → privremena', () async {
      handler = (_) => jsonResponse({
        'statusCode': '404',
        'error': 'not_found',
        'message': 'Object not found',
      }, 400);
      await expectLater(
        SupabasePhotoRemote(client).download('h1/x.jpg'),
        throwsA(isA<PermanentSyncError>()),
      );
      handler = (_) => http.Response('down', 503);
      await expectLater(
        SupabasePhotoRemote(client).download('h1/x.jpg'),
        throwsA(isA<TransientSyncError>()),
      );
    });
  });
}
