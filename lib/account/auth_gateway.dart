import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart' as sb;

import '../data/socket_exception.dart';
import '../domain/account.dart';
import 'supabase_client.dart';

/// Prijavljena sesija. [json] je ceo zapis sesije (tokeni) koji se čuva
/// samo u sistemskom bezbednom skladištu (`SessionStore`); nikad u bazi ili logu.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.json,
  });

  final String userId;
  final String email;
  final String json;

  /// Bez tokena, da ne završi u logu.
  @override
  String toString() => 'AuthSession($userId)';
}

/// Zašto prijava ili obnova sesije nije uspela. Tekst za korisnika daje
/// `authErrorText` (lib/features/account/auth_error_text.dart).
sealed class AuthFailure implements Exception {
  const AuthFailure();

  @override
  String toString() => runtimeType.toString();
}

/// Kod nije ispravan (ili je zamenjen novijim).
class WrongCode extends AuthFailure {
  const WrongCode();
}

class CodeExpired extends AuthFailure {
  const CodeExpired();
}

class RateLimited extends AuthFailure {
  const RateLimited();
}

class Offline extends AuthFailure {
  const Offline();
}

/// Server ne radi ili aplikacija nema podešen Supabase.
class Unavailable extends AuthFailure {
  const Unavailable();
}

/// Sesija ne može da se obnovi (opozvana, istekla).
class SessionRevoked extends AuthFailure {
  const SessionRevoked();
}

/// Nalog više ne postoji (obrisan na drugom uređaju).
class AccountGone extends AuthFailure {
  const AccountGone();
}

/// Uređaj je odbio pristup sigurnom skladištu sesije.
class SecureStorageUnavailable extends AuthFailure {
  const SecureStorageUnavailable();
}

/// "Prijava" sa adresom za koju nalog ne postoji (prijava ne pravi nalog).
class NoAccount extends AuthFailure {
  const NoAccount();
}

/// "Registracija" sa adresom za koju nalog već postoji.
class AlreadyRegistered extends AuthFailure {
  const AlreadyRegistered();
}

/// Link iz mejla je istekao, već je iskorišćen ili je otvoren na drugom
/// uređaju (nema PKCE verifikatora).
class LinkExpired extends AuthFailure {
  const LinkExpired();
}

/// Adresa na koju vodi link iz mejla za potvrdu (supabase/config.toml:
/// `additional_redirect_urls`; isto i u oblaku).
const authCallbackUrl = 'tavli://auth-callback';

/// Kuda vodi dugme „Potvrdi adresu“ iz mejla. U oblaku je to https stranica
/// „Uspešna registracija“ (`site/potvrda/`), koja otvara [authCallbackUrl] sa
/// istim kodom; radi i kad mejl klijent ne otvara `tavli://` linkove.
/// Postavlja se u secrets.json (`AUTH_CONFIRM_PAGE_URL`) i mora biti među
/// Redirect URLs na Supabase-u. Bez nje (lokalni rad) link ide pravo u
/// aplikaciju.
const authEmailRedirectUrl = String.fromEnvironment(
  'AUTH_CONFIRM_PAGE_URL',
  defaultValue: authCallbackUrl,
);

/// Web (spec 036): adresa web aplikacije na koju vodi link iz mejla
/// (`WEB_AUTH_REDIRECT_URL` u secrets.json; mora biti među Redirect URLs).
/// Bez nje i na webu važi [authEmailRedirectUrl]; kod iz mejla radi u oba slučaja.
const webAuthRedirectUrl = String.fromEnvironment('WEB_AUTH_REDIRECT_URL');

/// Adresa za `emailRedirectTo`: na webu web adresa ako je zadata, inače [authEmailRedirectUrl].
String get emailRedirectTarget => kIsWeb && webAuthRedirectUrl.isNotEmpty
    ? webAuthRedirectUrl
    : authEmailRedirectUrl;

/// Web: kad je stranica otvorena iz mejla (`?code=` ili `?error=`), vraća isti
/// povratak kao `tavli://auth-callback` da ga obradi postojeći tok; inače null.
Uri? webAuthCallbackFrom(Uri pageUri) {
  final q = pageUri.queryParameters;
  if (!q.containsKey('code') &&
      !q.containsKey('error') &&
      !q.containsKey('error_code')) {
    return null;
  }
  return Uri(scheme: 'tavli', host: 'auth-callback', queryParameters: q);
}

/// Da li je [uri] povratak iz mejla za potvrdu.
bool isAuthCallback(Uri uri) =>
    uri.scheme == 'tavli' && uri.host == 'auth-callback';

/// Prijava e-poštom i kodom, registracija mejlom za potvrdu (Supabase Auth).
abstract interface class AuthGateway {
  /// "Prijava": šalje 6-cifreni kod postojećem nalogu. Ne pravi nalog;
  /// za nepoznatu adresu baca [NoAccount].
  Future<void> sendCode(String email);

  /// "Registracija": pravi nalog i šalje mejl za potvrdu (dugme koje vodi
  /// na [authCallbackUrl] i 6-cifreni kod). Baca [AlreadyRegistered] za
  /// potvrđenu adresu. Vraća sesiju samo kad server ne traži potvrdu
  /// adrese (tada je osoba odmah prijavljena), inače null.
  Future<AuthSession?> signUp(String email);

  /// "Pošalji mejl ponovo" na ekranu "Proveri mejl".
  Future<void> resendConfirmation(String email);

  /// Proverava kod iz mejla (prijava ili potvrda adrese).
  Future<AuthSession> verifyCode(String email, String code);

  /// Prijava linkom iz mejla za potvrdu (PKCE: kod iz linka + verifikator
  /// sačuvan pri slanju). Baca [LinkExpired] za istekao/iskorišćen link.
  Future<AuthSession> exchangeLink(Uri link);

  /// Vraća sačuvanu sesiju (i obnavlja je ako je istekla).
  Future<AuthSession> restore(String sessionJson);

  /// Obnavlja trenutnu sesiju (posle odgovora 401).
  Future<AuthSession> refresh();

  /// Obnovljena sesija (za ponovno čuvanje) ili null kad je odjavljena.
  Stream<AuthSession?> get sessionChanges;

  /// Odjava samo na ovom uređaju.
  Future<void> signOutLocal();
}

/// Kad aplikacija nema Supabase adresu i ključ (build bez `secrets.json`):
/// prijava nije dostupna, ali aplikacija ne puca.
class UnconfiguredAuthGateway implements AuthGateway {
  const UnconfiguredAuthGateway();

  @override
  Future<void> sendCode(String email) async => throw const Unavailable();

  @override
  Future<AuthSession?> signUp(String email) async => throw const Unavailable();

  @override
  Future<void> resendConfirmation(String email) async =>
      throw const Unavailable();

  @override
  Future<AuthSession> verifyCode(String email, String code) async =>
      throw const Unavailable();

  @override
  Future<AuthSession> exchangeLink(Uri link) async => throw const Unavailable();

  @override
  Future<AuthSession> restore(String sessionJson) async =>
      throw const Unavailable();

  @override
  Future<AuthSession> refresh() async => throw const Unavailable();

  @override
  Stream<AuthSession?> get sessionChanges => const Stream.empty();

  @override
  Future<void> signOutLocal() async {}
}

/// Prijava preko Supabase Auth (GoTrue): e-poštom i 6-cifrenim kodom ili
/// linkom za potvrdu (PKCE).
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(
    this._client, {
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final sb.SupabaseClient _client;
  final DateTime Function() _clock;
  final Random _random;

  /// Kada je poslat poslednji kod, po adresi: GoTrue vraća istu grešku za
  /// pogrešan i istekao kod, pa se razlikuju po vremenu.
  final _sentAt = <String, DateTime>{};

  /// Koliko kod važi (`otp_expiry` u supabase/config.toml).
  static const codeLifetime = Duration(seconds: 600);

  sb.GoTrueClient get _auth => _client.auth;

  @override
  Future<void> sendCode(String email) async {
    final e = normalizeEmail(email);
    await _guard(
      () => _auth.signInWithOtp(
        email: e,
        shouldCreateUser: false,
        // Nepotvrđenoj adresi server šalje mejl za potvrdu, sa linkom.
        emailRedirectTo: emailRedirectTarget,
      ),
    );
    _sentAt[e] = _clock();
  }

  @override
  Future<AuthSession?> signUp(String email) async {
    final e = normalizeEmail(email);
    final res = await _guard(
      () => _auth.signUp(
        email: e,
        // Prijava je samo kodom ili linkom; lozinku server traži za nalog,
        // a ovu niko ne zna niti čuva.
        password: _unusedPassword(),
        emailRedirectTo: emailRedirectTarget,
      ),
    );
    final session = res.session;
    if (session != null) return _toSession(session);
    // Potvrđena adresa: server ne šalje mejl i vraća nalog bez identiteta.
    final identities = res.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AlreadyRegistered();
    }
    _sentAt[e] = _clock();
    return null;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    final e = normalizeEmail(email);
    await _guard(
      () => _auth.resend(
        type: sb.OtpType.signup,
        email: e,
        emailRedirectTo: emailRedirectTarget,
      ),
    );
    _sentAt[e] = _clock();
  }

  String _unusedPassword() =>
      base64Url.encode(List.generate(32, (_) => _random.nextInt(256)));

  @override
  Future<AuthSession> verifyCode(String email, String code) async {
    final e = normalizeEmail(email);
    try {
      final res = await _guard(
        () => _auth.verifyOTP(
          type: sb.OtpType.email,
          email: e,
          token: normalizeCode(code),
        ),
        onCodeError: () {
          final sent = _sentAt[e];
          final expired =
              sent != null && _clock().difference(sent) > codeLifetime;
          return expired ? const CodeExpired() : const WrongCode();
        },
      );
      final session = res.session;
      if (session == null) throw const Unavailable();
      return _toSession(session);
    } on FormatException {
      throw const Unavailable();
    }
  }

  @override
  Future<AuthSession> exchangeLink(Uri link) async {
    // GoTrue vraća grešku (npr. otp_expired) u upitu ili fragmentu.
    final params = {
      ...link.queryParameters,
      if (link.fragment.isNotEmpty) ...Uri.splitQueryString(link.fragment),
    };
    final code = params['code'];
    if (params.containsKey('error') ||
        params.containsKey('error_code') ||
        code == null ||
        code.isEmpty) {
      throw const LinkExpired();
    }
    try {
      final res = await _guard(
        () => _auth.exchangeCodeForSession(code),
        link: true,
      );
      return _toSession(res.session);
    } on FormatException {
      throw const Unavailable();
    }
  }

  @override
  Future<AuthSession> restore(String sessionJson) async {
    try {
      final res = await _guard(
        () => _auth.recoverSession(sessionJson),
        refreshing: true,
      );
      final session = res.session;
      if (session == null) throw const SessionRevoked();
      return _toSession(session);
    } on FormatException {
      throw const SessionRevoked();
    }
  }

  @override
  Future<AuthSession> refresh() async {
    final res = await _guard(_auth.refreshSession, refreshing: true);
    final session = res.session;
    if (session == null) throw const SessionRevoked();
    return _toSession(session);
  }

  @override
  Stream<AuthSession?> get sessionChanges => _auth.onAuthStateChange
      .where(
        (s) =>
            s.event == sb.AuthChangeEvent.tokenRefreshed ||
            s.event == sb.AuthChangeEvent.signedOut,
      )
      .map((s) => s.session == null ? null : _toSession(s.session!))
      .handleError((Object _) {}, test: (e) => e is sb.AuthException);

  @override
  Future<void> signOutLocal() async {
    try {
      await _auth.signOut();
    } on sb.AuthException {
      // Lokalna sesija je svakako obrisana.
    }
  }

  static AuthSession _toSession(sb.Session s) => AuthSession(
    userId: s.user.id,
    email: normalizeEmail(s.user.email ?? ''),
    json: jsonEncodeSession(s),
  );

  /// Pretvara greške klijenta u [AuthFailure]; nikad ne prenosi poruku
  /// servera (može da sadrži token).
  static Future<T> _guard<T>(
    Future<T> Function() action, {
    bool refreshing = false,
    bool link = false,
    AuthFailure Function()? onCodeError,
  }) async {
    try {
      return await action();
    } on sb.AuthRetryableFetchException catch (e) {
      throw e.statusCode == null ? const Offline() : const Unavailable();
    } on sb.AuthApiException catch (e) {
      if (link && _linkErrors.contains(e.code)) throw const LinkExpired();
      throw _apiFailure(e, refreshing, onCodeError);
    } on sb.AuthException catch (e) {
      // Nema verifikatora: link otvoren na drugom uređaju ili već iskorišćen.
      if (link) throw const LinkExpired();
      // recoverSession bez osveživača ili sa pokvarenim zapisom.
      if (refreshing &&
          (e.code == 'session_expired' || e.code == 'session_missing')) {
        throw const SessionRevoked();
      }
      throw const Unavailable();
    } on SocketException {
      throw const Offline();
    } on TimeoutException {
      throw const Offline();
    } on http.ClientException {
      throw const Offline();
    }
  }

  static const _linkErrors = {
    'flow_state_not_found',
    'flow_state_expired',
    'bad_code_verifier',
    'otp_expired',
    'validation_failed',
  };

  static const _revoked = {
    'refresh_token_not_found',
    'refresh_token_already_used',
    'session_not_found',
    'session_expired',
    'bad_jwt',
  };

  static AuthFailure _apiFailure(
    sb.AuthApiException e,
    bool refreshing,
    AuthFailure Function()? onCodeError,
  ) {
    final code = e.code;
    if (e.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return const RateLimited();
    }
    // Prijava sa nepoznatom adresom (shouldCreateUser: false).
    if (code == 'otp_disabled') return const NoAccount();
    // Registracija kad server ne traži potvrdu adrese (mailer_autoconfirm).
    if (code == 'user_already_exists' || code == 'email_exists') {
      return const AlreadyRegistered();
    }
    if (code == 'user_not_found') return const AccountGone();
    if (onCodeError != null &&
        (code == 'otp_expired' ||
            e.message.contains('expired or is invalid'))) {
      return onCodeError();
    }
    if (_revoked.contains(code)) return const SessionRevoked();
    final status = int.tryParse(e.statusCode ?? '');
    if (refreshing && status != null && status >= 400 && status < 500) {
      return const SessionRevoked();
    }
    return const Unavailable();
  }
}
