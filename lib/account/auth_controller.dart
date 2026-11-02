import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/key_store.dart';
import '../domain/account.dart';
import '../providers.dart';
import 'account_service.dart';
import 'auth_gateway.dart';
import 'session_store.dart';

/// Čiji su podaci: lični podaci pripadaju osobi ([userId]), a podaci
/// domaćinstva domaćinstvu ([householdId]).
class AccountScope {
  const AccountScope({required this.userId, required this.householdId});

  final String userId;
  final String householdId;

  @override
  bool operator ==(Object other) =>
      other is AccountScope &&
      other.userId == userId &&
      other.householdId == householdId;

  @override
  int get hashCode => Object.hash(userId, householdId);

  @override
  String toString() => 'AccountScope($userId, $householdId)';
}

/// Ne odgovara nijednom zapisu (niko nije prijavljen).
const noAccountScope = AccountScope(userId: '', householdId: '');

enum SignOutReason { sessionExpired, accountDeleted }

/// Stanje prijave. `CodeSent` se nikad ne čuva: posle ponovnog otvaranja
/// aplikacije prikazuje se korak sa e-poštom.
sealed class AuthState {
  const AuthState();
}

/// Čita se sačuvana sesija (kratko, bez mreže).
class Starting extends AuthState {
  const Starting();
}

class SignedOut extends AuthState {
  const SignedOut([this.reason]);

  final SignOutReason? reason;
}

class CodeSent extends AuthState {
  const CodeSent(this.email, this.sentAt);

  final String email;
  final DateTime sentAt;
}

/// Prijavljen, ali još bez imena (obavezan korak).
class NeedsName extends AuthState {
  const NeedsName(this.account);

  final Account account;
}

class SignedIn extends AuthState {
  const SignedIn(this.account);

  final Account account;
}

/// userId iz sačuvanog JSON-a sesije (bez mreže).
String? userIdFromSessionJson(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return null;
    final user = decoded['user'];
    final id = user is Map ? user['id'] : null;
    return id is String ? id : null;
  } on FormatException {
    return null;
  }
}

class AuthController extends Notifier<AuthState> {
  StreamSubscription<AuthSession?>? _sessions;

  AuthGateway get _gateway => ref.read(authGatewayProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  AccountService get _service => ref.read(accountServiceProvider);

  @override
  AuthState build() {
    // Obnovljena sesija se odmah ponovo čuva.
    _sessions = ref
        .watch(authGatewayProvider)
        .sessionChanges
        .listen(_onSessionChanged);
    ref.onDispose(() => _sessions?.cancel());
    return const Starting();
  }

  /// Otvara aplikaciju iz sačuvane sesije i keširanog naloga, bez mreže.
  /// Sesija se obnavlja u pozadini kad ima mreže.
  Future<void> start() async {
    final store = _store, gateway = _gateway, service = _service;
    final String? json;
    try {
      json = await store.read();
    } on SecretStorageException {
      _set(const SignedOut());
      return;
    }
    final uid = json == null ? null : userIdFromSessionJson(json);
    if (json == null || uid == null) {
      _set(const SignedOut());
      return;
    }
    final account = await service.cached(uid);
    if (account != null) {
      _set(_signedIn(account));
      unawaited(restoreSession());
      return;
    }
    // Sesija postoji, ali nalog nije keširan (prekinuta prva prijava).
    try {
      final session = await gateway.restore(json);
      await store.write(session.json);
      _set(_signedIn(await service.loadOrFetch(session)));
    } on AuthFailure {
      _set(const SignedOut());
    }
  }

  /// Obnavlja sačuvanu sesiju (start, povratak u aplikaciju). Bez mreže
  /// ostaje prijavljen; odbijena obnova vraća na prijavu.
  Future<void> restoreSession() async {
    if (!ref.mounted) return;
    final store = _store, gateway = _gateway;
    final json = await store.read();
    if (json == null) return;
    try {
      final session = await gateway.restore(json);
      if (ref.mounted) await store.write(session.json);
    } on Offline {
      // Pokušava se ponovo pri povratku u aplikaciju.
    } on Unavailable {
      // Isto.
    } on AuthFailure catch (f) {
      if (ref.mounted) await sessionExpired(accountGone: f is AccountGone);
    }
  }

  /// Šalje kod (i ponovo, posle 30 s). Baca [AuthFailure]; stanje ostaje.
  Future<void> sendCode(String email) async {
    final e = normalizeEmail(email);
    final clock = ref.read(authClockProvider);
    await _gateway.sendCode(e);
    _set(CodeSent(e, clock()));
  }

  /// Proverava kod; ispravan kod čuva sesiju i otvara aplikaciju (ili
  /// korak sa imenom). Baca [AuthFailure]; stanje ostaje.
  Future<void> verify(String code) async {
    final s = state;
    if (s is! CodeSent) return;
    final store = _store, service = _service;
    final session = await _gateway.verifyCode(s.email, normalizeCode(code));
    await store.write(session.json);
    _set(_signedIn(await service.loadOrFetch(session)));
  }

  /// Čuva ime (obavezan korak ili "Izmeni ime"). Baca [ArgumentError] za
  /// prazno ili predugo ime.
  Future<void> saveName(String name) async {
    final account = switch (state) {
      NeedsName(:final account) || SignedIn(:final account) => account,
      _ => null,
    };
    if (account == null) return;
    _set(SignedIn(await _service.saveName(account, name)));
  }

  /// "Promeni e-poštu": nazad na prvi korak.
  void changeEmail() => state = const SignedOut();

  /// Posle čekanja kontroler je možda već uklonjen (test, odjava).
  void _set(AuthState s) {
    if (ref.mounted) state = s;
  }

  AuthState _signedIn(Account a) => a.hasName ? SignedIn(a) : NeedsName(a);

  Future<void> _onSessionChanged(AuthSession? session) async {
    if (session == null) return;
    if (state is SignedIn || state is NeedsName) {
      await _store.write(session.json);
    }
  }

  /// Sesija ne može da se obnovi: nazad na prijavu, keš i izmene ostaju.
  Future<void> sessionExpired({bool accountGone = false}) async {
    final store = _store, gateway = _gateway;
    await store.clear();
    await gateway.signOutLocal();
    _set(const SignedOut(SignOutReason.sessionExpired));
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Nalog čiji se podaci prikazuju; null dok niko nije prijavljen.
final accountScopeProvider = Provider<AccountScope?>(
  (ref) => switch (ref.watch(authControllerProvider)) {
    SignedIn(:final account) => AccountScope(
      userId: account.userId,
      householdId: account.householdId,
    ),
    _ => null,
  },
);
