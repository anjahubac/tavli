import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:tavli/account/account_api.dart';
import 'package:tavli/account/account_service.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/supabase_client.dart';
import 'package:tavli/account/supabase_config.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/domain/account.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_supabase.dart';

void main() {
  group('SupabaseAccountApi.fetch', () {
    late SupabaseClient client;
    late List<http.Request> requests;
    late http.Response Function(http.Request) handler;

    setUp(() async {
      requests = [];
      client = createSupabaseClient(
        const SupabaseConfig(url: fakeUrl, anonKey: fakeAnonKey),
        httpClient: mockHttp((r) {
          requests.add(r);
          return handler(r);
        }),
      );
      // Važeća sesija se vraća bez mreže.
      handler = (_) => throw StateError('nema mreže u testu');
      await client.auth.recoverSession(jsonEncode(sessionBody()));
    });
    tearDown(() => client.dispose());

    SupabaseAccountApi api() =>
        SupabaseAccountApi(client, retryDelay: Duration.zero);

    final profile = {
      'id': 'u1',
      'email': 'ana@mail.com',
      'display_name': 'Ana Petrović',
    };
    final membership = {
      'household_id': 'h1',
      'role': 'owner',
      'households': {'name': 'Moje domaćinstvo'},
    };

    test('čita svoj profil, članstvo i domaćinstvo', () async {
      handler = (r) => jsonResponse(
        r.url.path.endsWith('/profiles') ? [profile] : [membership],
      );
      final a = await api().fetch();
      expect(a.userId, 'u1');
      expect(a.displayName, 'Ana Petrović');
      expect(a.householdId, 'h1');
      expect(a.householdName, 'Moje domaćinstvo');
      expect(a.role, 'owner');
      final p = requests.firstWhere((r) => r.url.path.endsWith('/profiles'));
      expect(p.url.queryParameters['id'], 'eq.u1');
      final m = requests.firstWhere(
        (r) => r.url.path.endsWith('/household_members'),
      );
      expect(m.url.queryParameters['user_id'], 'eq.u1');
    });

    test('ponavlja dok red iz okidača ne postane vidljiv', () async {
      var calls = 0;
      handler = (r) {
        if (r.url.path.endsWith('/household_members')) {
          return jsonResponse(++calls < 3 ? <Object>[] : [membership]);
        }
        return jsonResponse([profile]);
      };
      final a = await api().fetch();
      expect(a.householdId, 'h1');
      expect(calls, 3);
    });

    test('posle tri pokušaja bez reda: nedostupno', () async {
      handler = (r) => jsonResponse(<Object>[]);
      await expectLater(api().fetch(), throwsA(isA<Unavailable>()));
    });

    test('bez mreže i 401', () async {
      handler = (_) => throw const SocketException('nema mreže');
      await expectLater(api().fetch(), throwsA(isA<Offline>()));
      handler = (_) =>
          jsonResponse({'code': 'PGRST301', 'message': 'JWT expired'}, 401);
      await expectLater(api().fetch(), throwsA(isA<SessionRevoked>()));
    });
  });

  group('AccountService', () {
    late AppDatabase db;
    late FakeBackend backend;
    late AccountService service;
    var kicks = 0;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      backend = FakeBackend();
      kicks = 0;
      service = AccountService(
        db,
        backend.accounts,
        clock: () => DateTime.utc(2026),
        onChange: () => kicks++,
      );
    });
    tearDown(() => db.close());

    Future<AuthSession> signIn() =>
        backend.auth.verifyCode('ana@mail.com', FakeServer.code);

    test('loadOrFetch upisuje nalog na uređaj, pa radi bez mreže', () async {
      final s = await signIn();
      final a = await service.loadOrFetch(s);
      expect(a.householdName, 'Moje domaćinstvo');
      expect(a.displayName, isNull);
      final row = (await db.select(db.accounts).get()).single;
      expect(row.userId, s.userId);
      expect(row.email, 'ana@mail.com');

      backend.server.offline = true;
      expect((await service.loadOrFetch(s)).userId, s.userId);
      expect(await service.cached('nema'), isNull);
    });

    test('saveName skida razmake, čuva lokalno i šalje profil', () async {
      final a = await service.loadOrFetch(await signIn());
      final named = await service.saveName(a, '  Ana Petrović ');
      expect(named.displayName, 'Ana Petrović');
      expect((await service.cached(a.userId))!.displayName, 'Ana Petrović');
      final e = (await db.select(db.syncOutbox).get()).single;
      expect('${e.entity}:${e.recordId}:${e.op}', 'profile:${a.userId}:upsert');
      expect(e.accountId, a.userId);
      expect(kicks, 1);
    });

    test('prazno i predugo ime se odbija', () async {
      final a = await service.loadOrFetch(await signIn());
      expect(() => service.saveName(a, '   '), throwsArgumentError);
      expect(
        () => service.saveName(a, 'a' * (maxNameLength + 1)),
        throwsArgumentError,
      );
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    });

    test('postojeći nalog sa imenom ne traži ime', () async {
      final uid = backend.server.userFor('ana@mail.com');
      backend.server.profiles[uid]!['display_name'] = 'Ana';
      final a = await service.loadOrFetch(await signIn());
      expect(a.hasName, isTrue);
      expect(a.displayName, 'Ana');
    });
  });
}
