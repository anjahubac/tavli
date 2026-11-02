import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:tavli/account/auth_gateway.dart';
import 'package:tavli/account/supabase_client.dart';
import 'package:tavli/account/supabase_config.dart';

import '../helpers/fake_supabase.dart';

void main() {
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;
  late SupabaseClient client;
  late DateTime now;

  SupabaseAuthGateway gateway() =>
      SupabaseAuthGateway(client, clock: () => now);

  setUp(() {
    requests = [];
    now = DateTime(2026, 10, 30, 12);
    handler = (_) => jsonResponse({});
    client = createSupabaseClient(
      const SupabaseConfig(url: fakeUrl, anonKey: fakeAnonKey),
      httpClient: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
  });
  tearDown(() => client.dispose());

  Map<String, Object?> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, Object?>;

  test('sendCode šalje sređenu e-poštu i pravi nalog ako ga nema', () async {
    await gateway().sendCode(' Ana@Mail.com ');
    final r = requests.single;
    expect(r.url.path, '/auth/v1/otp');
    expect(body(r)['email'], 'ana@mail.com');
    expect(body(r)['create_user'], isTrue);
  });

  test('verifyCode vraća sesiju', () async {
    handler = (_) => jsonResponse(sessionBody());
    final s = await gateway().verifyCode('Ana@mail.com', '123 456');
    expect(s.userId, 'u1');
    expect(s.email, 'ana@mail.com');
    expect(jsonDecode(s.json), containsPair('refresh_token', 'fake-refresh'));
    final r = requests.single;
    expect(r.url.path, '/auth/v1/verify');
    expect(body(r)['token'], '123456');
    expect(body(r)['type'], 'email');
    expect(body(r)['email'], 'ana@mail.com');
    expect(s.toString(), isNot(contains('fake-refresh')));
  });

  group('greške', () {
    http.Response otpExpired(http.Request _) => jsonResponse({
      'code': 403,
      'error_code': 'otp_expired',
      'msg': 'Token has expired or is invalid',
    }, 403);

    test('pogrešan kod dok kod još važi', () async {
      final g = gateway();
      await g.sendCode('ana@mail.com');
      handler = otpExpired;
      now = now.add(const Duration(minutes: 9));
      await expectLater(
        g.verifyCode('ana@mail.com', '000000'),
        throwsA(isA<WrongCode>()),
      );
    });

    test('kod stariji od 10 minuta je istekao', () async {
      final g = gateway();
      await g.sendCode('ana@mail.com');
      handler = otpExpired;
      now = now.add(const Duration(minutes: 11));
      await expectLater(
        g.verifyCode('ana@mail.com', '123456'),
        throwsA(isA<CodeExpired>()),
      );
    });

    test('previše zahteva', () async {
      handler = (_) => jsonResponse({
        'code': 429,
        'error_code': 'over_email_send_rate_limit',
        'msg': 'email rate limit exceeded',
      }, 429);
      await expectLater(
        gateway().sendCode('ana@mail.com'),
        throwsA(isA<RateLimited>()),
      );
    });

    test('bez mreže i istek vremena', () async {
      handler = (_) => throw const SocketException('nema mreže');
      await expectLater(
        gateway().sendCode('ana@mail.com'),
        throwsA(isA<Offline>()),
      );
      handler = (_) => throw TimeoutException('spor');
      await expectLater(
        gateway().verifyCode('ana@mail.com', '123456'),
        throwsA(isA<Offline>()),
      );
    });

    test('server ne radi (5xx)', () async {
      handler = (_) => http.Response('upstream error', 503);
      await expectLater(
        gateway().sendCode('ana@mail.com'),
        throwsA(isA<Unavailable>()),
      );
    });

    test('bez Supabase podešavanja prijava nije dostupna', () async {
      await expectLater(
        const UnconfiguredAuthGateway().sendCode('ana@mail.com'),
        throwsA(isA<Unavailable>()),
      );
    });

    test('odbijena obnova sesije i obrisan nalog', () async {
      final expired = jsonEncode(
        sessionBody(validFor: const Duration(hours: -2)),
      );
      handler = (_) => jsonResponse({
        'code': 400,
        'error_code': 'refresh_token_not_found',
        'msg': 'Invalid Refresh Token: Refresh Token Not Found',
      }, 400);
      await expectLater(
        gateway().restore(expired),
        throwsA(isA<SessionRevoked>()),
      );
      handler = (_) => jsonResponse({
        'code': 403,
        'error_code': 'user_not_found',
        'msg': 'User from sub claim in JWT does not exist',
      }, 403);
      await expectLater(
        gateway().restore(expired),
        throwsA(isA<AccountGone>()),
      );
    });

    test('obnova bez mreže ostavlja sesiju', () async {
      final expired = jsonEncode(
        sessionBody(validFor: const Duration(hours: -2)),
      );
      handler = (_) => throw const SocketException('nema mreže');
      await expectLater(gateway().restore(expired), throwsA(isA<Offline>()));
    });

    test('važeća sesija se vraća bez mreže', () async {
      handler = (_) => throw const SocketException('nema mreže');
      final s = await gateway().restore(jsonEncode(sessionBody()));
      expect(s.userId, 'u1');
      expect(requests, isEmpty);
    });

    test('tekst greške nikad ne sadrži ključ ni token', () async {
      handler = (_) => jsonResponse({
        'code': 400,
        'error_code': 'refresh_token_not_found',
        'msg': 'fake-refresh',
      }, 400);
      try {
        await gateway().restore(
          jsonEncode(sessionBody(validFor: const Duration(hours: -2))),
        );
        fail('očekivana greška');
      } on AuthFailure catch (f) {
        expect(f.toString(), isNot(contains('fake')));
      }
    });
  });
}
