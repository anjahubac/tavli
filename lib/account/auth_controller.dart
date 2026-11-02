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
    final String? json;
    try {
      json = await _store.read();
    } on SecretStorageException {
      state = const SignedOut();
      return;
    }
    final uid = json == null ? null : userIdFromSessionJson(json);
    if (json == null || uid == null) {
      state = const SignedOut();
      return;
    }
    final account = await _service.cached(uid);
    if (account != null) {
      state = _signedIn(account);
      unawaited(restoreSession());
      return;
    }
    // Sesija postoji, ali nalog nije keširan (prekinuta prva prijava).
    try {
      final session = await _gateway.restore(json);
      await _store.write(session.json);
      state = _signedIn(await _service.loadOrFetch(session));
    } on AuthFailure {
      state = const SignedOut();
    }
  }

  /// Obnavlja sačuvanu sesiju (start, povratak u aplikaciju). Bez mreže
  /// ostaje prijavljen; odbijena obnova vraća na prijavu.
  Future<void> restoreSession() async {
    final json = await _store.read();
    if (json == null) return;
    try {
      final session = await _gateway.restore(json);
      await _store.write(session.json);
    } on Offline {
      // Pokušava se ponovo pri povratku u aplikaciju.
    } on Unavailable {
      // Isto.
    } on AuthFailure catch (f) {
      await sessionExpired(accountGone: f is AccountGone);
    }
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
    await _store.clear();
    await _gateway.signOutLocal();
    state = const SignedOut(SignOutReason.sessionExpired);
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
