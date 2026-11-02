import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart' as sb;

import '../domain/account.dart';
import 'supabase_client.dart';

/// Prijavljena sesija. [json] je ceo zapis sesije (tokeni) koji se čuva
/// samo u Keychain-u/Keystore-u (`SessionStore`); nikad u bazi ili logu.
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

/// Prijava e-poštom i kodom (Supabase Auth).
abstract interface class AuthGateway {
  /// Šalje 6-cifreni kod; isti tok pravi nov nalog ili prijavljuje postojeći.
  Future<void> sendCode(String email);

  Future<AuthSession> verifyCode(String email, String code);

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
  Future<AuthSession> verifyCode(String email, String code) async =>
      throw const Unavailable();

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

/// Prijava preko Supabase Auth (GoTrue), e-poštom i 6-cifrenim kodom.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final sb.SupabaseClient _client;
  final DateTime Function() _clock;

  /// Kada je poslat poslednji kod, po adresi: GoTrue vraća istu grešku za
  /// pogrešan i istekao kod, pa se razlikuju po vremenu.
  final _sentAt = <String, DateTime>{};

  /// Koliko kod važi (`otp_expiry` u supabase/config.toml).
  static const codeLifetime = Duration(seconds: 600);

  sb.GoTrueClient get _auth => _client.auth;

  @override
  Future<void> sendCode(String email) async {
    final e = normalizeEmail(email);
    await _guard(() => _auth.signInWithOtp(email: e, shouldCreateUser: true));
    _sentAt[e] = _clock();
  }

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
    AuthFailure Function()? onCodeError,
  }) async {
    try {
      return await action();
    } on sb.AuthRetryableFetchException catch (e) {
      throw e.statusCode == null ? const Offline() : const Unavailable();
    } on sb.AuthApiException catch (e) {
      throw _apiFailure(e, refreshing, onCodeError);
    } on sb.AuthException catch (e) {
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
