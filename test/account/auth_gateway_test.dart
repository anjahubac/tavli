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

import '../helpers/fake_secret_storage.dart';
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
      secrets: MapSecretStorage(),
      httpClient: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
  });
  tearDown(() => client.dispose());

  Map<String, Object?> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, Object?>;

  test('sendCode šalje sređenu e-poštu i ne pravi nalog', () async {
    await gateway().sendCode(' Ana@Mail.com ');
    final r = requests.single;
    expect(r.url.path, '/auth/v1/otp');
    expect(body(r)['email'], 'ana@mail.com');
    expect(body(r)['create_user'], isFalse);
  });

  test('sendCode za nepoznatu adresu: NoAccount', () async {
    handler = (_) => jsonResponse({
      'code': 422,
      'error_code': 'otp_disabled',
      'msg': 'Signups not allowed for otp',
    }, 422);
    await expectLater(
      gateway().sendCode('nova@mail.com'),
      throwsA(isA<NoAccount>()),
    );
  });

  group('signUp', () {
    Map<String, Object?> user({required bool withIdentity}) => {
      'id': 'u1',
      'aud': 'authenticated',
      'email': 'ana@mail.com',
      'created_at': '2026-11-21T12:00:00Z',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'identities': [
        if (withIdentity)
          {
            'id': 'u1',
            'identity_id': 'i1',
            'user_id': 'u1',
            'provider': 'email',
            'identity_data': {'sub': 'u1', 'email': 'ana@mail.com'},
            'created_at': '2026-11-21T12:00:00Z',
            'last_sign_in_at': '2026-11-21T12:00:00Z',
            'updated_at': '2026-11-21T12:00:00Z',
          },
      ],
    };

    test('nova adresa: mejl za potvrdu sa linkom, bez sesije', () async {
      handler = (_) => jsonResponse(user(withIdentity: true));
      final s = await gateway().signUp(' Ana@Mail.com ');
      expect(s, isNull);
      final r = requests.single;
      expect(r.url.path, '/auth/v1/signup');
      expect(r.url.queryParameters['redirect_to'], authEmailRedirectUrl);
      expect(body(r)['email'], 'ana@mail.com');
      // Nasumična lozinka koju niko ne koristi; PKCE izazov za link.
      expect((body(r)['password']! as String).length, greaterThan(30));
      expect(body(r)['code_challenge'], isNotNull);
    });

    test('dve registracije imaju različite lozinke', () async {
      handler = (_) => jsonResponse(user(withIdentity: true));
      await gateway().signUp('ana@mail.com');
      await gateway().signUp('ana@mail.com');
      expect(
        body(requests[0])['password'],
        isNot(body(requests[1])['password']),
      );
    });

    test('potvrđena adresa (bez identiteta): AlreadyRegistered', () async {
      handler = (_) => jsonResponse(user(withIdentity: false));
      await expectLater(
        gateway().signUp('ana@mail.com'),
        throwsA(isA<AlreadyRegistered>()),
      );
    });

    test('server bez potvrde adrese: user_already_exists', () async {
      handler = (_) => jsonResponse({
        'code': 422,
        'error_code': 'user_already_exists',
        'msg': 'User already registered',
      }, 422);
      await expectLater(
        gateway().signUp('ana@mail.com'),
        throwsA(isA<AlreadyRegistered>()),
      );
    });

    test('server bez potvrde adrese: odmah sesija', () async {
      handler = (_) => jsonResponse(sessionBody());
      final s = await gateway().signUp('ana@mail.com');
      expect(s?.userId, 'u1');
    });
  });

  test('resendConfirmation: mejl za potvrdu sa linkom', () async {
    handler = (_) => jsonResponse(<String, Object?>{});
    await gateway().resendConfirmation('Ana@Mail.com');
    final r = requests.single;
    expect(r.url.path, '/auth/v1/resend');
    expect(body(r)['type'], 'signup');
    expect(body(r)['email'], 'ana@mail.com');
    expect(r.url.queryParameters['redirect_to'], authEmailRedirectUrl);
  });

  group('exchangeLink', () {
    test('greška u linku: LinkExpired bez poziva servera', () async {
      await expectLater(
        gateway().exchangeLink(
          Uri.parse(
            '$authCallbackUrl#error=access_denied&error_code=otp_expired',
          ),
        ),
        throwsA(isA<LinkExpired>()),
      );
      expect(requests, isEmpty);
    });

    test('bez verifikatora (drugi uređaj): LinkExpired', () async {
      await expectLater(
        gateway().exchangeLink(Uri.parse('$authCallbackUrl?code=abc')),
        throwsA(isA<LinkExpired>()),
      );
    });
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

    // GoTrue ponavlja osvežavanje bez mreže uz pravo čekanje (~12 s);
    // testWidgets ga vrti na lažnom satu, pa test traje trenutak.
    testWidgets('obnova bez mreže ostavlja sesiju', (tester) async {
      final expired = jsonEncode(
        sessionBody(validFor: const Duration(hours: -2)),
      );
      handler = (_) => throw const SocketException('nema mreže');
      final restored = expectLater(
        gateway().restore(expired),
        throwsA(isA<Offline>()),
      );
      await tester.pump(const Duration(minutes: 1));
      await restored;
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
