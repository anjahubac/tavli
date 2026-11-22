import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/key_store.dart';
import '../domain/account.dart';
import '../providers.dart';
import 'account_api.dart';
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

enum SignOutReason { sessionExpired, accountDeleted, storageUnavailable }

/// Stanje prijave. `CodeSent` i `ConfirmSent` se nikad ne čuvaju: posle
/// ponovnog otvaranja aplikacije prikazuje se korak sa e-poštom (link iz
/// mejla za potvrdu i dalje prijavljuje, jer je PKCE verifikator sačuvan).
sealed class AuthState {
  const AuthState();
}

/// Čita se sačuvana sesija (kratko, bez mreže).
class Starting extends AuthState {
  const Starting();
}

class SignedOut extends AuthState {
  const SignedOut([this.reason, this.linkError]);

  final SignOutReason? reason;

  /// Link iz mejla nije uspeo (npr. [LinkExpired]) pre nego što je u ovom
  /// pokretanju poslat mejl.
  final AuthFailure? linkError;
}

/// "Prijava": kod je poslat postojećem nalogu ("Upiši kod").
class CodeSent extends AuthState {
  const CodeSent(this.email, this.sentAt);

  final String email;
  final DateTime sentAt;
}

/// "Registracija": poslat je mejl za potvrdu ("Proveri mejl"), sa dugmetom
/// i kodom.
class ConfirmSent extends AuthState {
  const ConfirmSent(this.email, this.sentAt, {this.linkError});

  final String email;
  final DateTime sentAt;

  /// Link iz mejla nije uspeo; prikazuje se uz "Pošalji mejl ponovo".
  final AuthFailure? linkError;
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
      _set(const SignedOut(SignOutReason.storageUnavailable));
      return;
    }
    final uid = json == null ? null : userIdFromSessionJson(json);
    if (json == null || uid == null) {
      _set(const SignedOut());
      return;
    }
    final account = await service.cached(uid);
    if (account != null && account.hasName) {
      _set(SignedIn(account));
      unawaited(restoreSession());
      return;
    }
    // Nalog nije keširan (prekinuta prva prijava) ili u kešu nema imena:
    // ime se možda već nalazi na serveru (drugi uređaj), pa se prvo pita
    // server. Korak sa imenom samo ako ga ni server nema ili nema mreže.
    try {
      final session = await gateway.restore(json);
      await store.write(session.json);
      _set(_signedIn(await service.loadOrFetch(session)));
    } on SecretStorageException {
      await _lockSession(gateway);
    } on AuthFailure catch (f) {
      if (account == null) {
        _set(const SignedOut());
      } else if (f is Offline || f is Unavailable) {
        _set(NeedsName(account));
      } else {
        _set(NeedsName(account));
        await sessionExpired(accountGone: f is AccountGone);
      }
    }
  }

  /// Obnavlja sačuvanu sesiju (start, povratak u aplikaciju). Bez mreže
  /// ostaje prijavljen; odbijena obnova vraća na prijavu.
  Future<void> restoreSession() async {
    if (!ref.mounted || !_hasAccount) return;
    final store = _store, gateway = _gateway;
    final String? json;
    try {
      json = await store.read();
    } on SecretStorageException {
      await _lockSession(gateway);
      return;
    }
    if (json == null) return;
    try {
      final session = await gateway.restore(json);
      if (ref.mounted) await store.write(session.json);
      if (ref.mounted && state is NeedsName) await _refetchName(session);
    } on SecretStorageException {
      await _lockSession(gateway);
    } on Offline {
      // Pokušava se ponovo pri povratku u aplikaciju.
    } on Unavailable {
      // Isto.
    } on AuthFailure catch (f) {
      if (ref.mounted) await sessionExpired(accountGone: f is AccountGone);
    }
  }

  /// "Prijava": šalje kod postojećem nalogu (i ponovo, posle 30 s). Baca
  /// [AuthFailure] ([NoAccount] za nepoznatu adresu); stanje ostaje.
  Future<void> sendCode(String email) async {
    final e = normalizeEmail(email);
    final clock = ref.read(authClockProvider);
    await _gateway.sendCode(e);
    _set(CodeSent(e, clock()));
  }

  /// "Registracija": pravi nalog i šalje mejl za potvrdu ("Proveri mejl").
  /// Kad server ne traži potvrdu adrese, odmah prijavljuje. Baca
  /// [AuthFailure] ([AlreadyRegistered] za postojeći nalog); stanje ostaje.
  Future<void> signUp(String email) async {
    final e = normalizeEmail(email);
    final clock = ref.read(authClockProvider);
    final session = await _gateway.signUp(e);
    if (session == null) {
      _set(ConfirmSent(e, clock()));
    } else {
      await _signInWith(session);
    }
  }

  /// "Pošalji mejl ponovo" na ekranu "Proveri mejl". Baca [AuthFailure].
  Future<void> resendConfirmation() async {
    final s = state;
    if (s is! ConfirmSent) return;
    final clock = ref.read(authClockProvider);
    await _gateway.resendConfirmation(s.email);
    _set(ConfirmSent(s.email, clock()));
  }

  /// "Pošalji mi kod" na ekranu "Proveri mejl" (adresa potvrđena na drugom
  /// uređaju): kod za prijavu se upisuje u isto polje. Baca [AuthFailure].
  Future<void> sendCodeInstead() async {
    final s = state;
    if (s is! ConfirmSent) return;
    final clock = ref.read(authClockProvider);
    await _gateway.sendCode(s.email);
    _set(ConfirmSent(s.email, clock()));
  }

  /// Proverava kod (prijava ili potvrda adrese); ispravan kod čuva sesiju
  /// i otvara aplikaciju (ili korak sa imenom). Baca [AuthFailure]; stanje
  /// ostaje.
  Future<void> verify(String code) async {
    final email = switch (state) {
      CodeSent(:final email) || ConfirmSent(:final email) => email,
      _ => null,
    };
    if (email == null) return;
    await _signInWith(await _gateway.verifyCode(email, normalizeCode(code)));
  }

  /// Link iz mejla za potvrdu ([authCallbackUrl]): prijavljuje novu adresu
  /// i otvara aplikaciju (ili jednom korak sa imenom). Greška (istekao ili
  /// iskorišćen link, bez mreže) ostaje u stanju, uz "Pošalji mejl
  /// ponovo". Ako je neko već prijavljen, link se zanemaruje.
  Future<void> openLink(Uri link) async {
    if (!isAuthCallback(link)) return;
    if (state is SignedIn || state is NeedsName) return;
    try {
      await _signInWith(await _gateway.exchangeLink(link));
    } on AuthFailure catch (f) {
      _set(switch (state) {
        ConfirmSent(:final email, :final sentAt) => ConfirmSent(
          email,
          sentAt,
          linkError: f,
        ),
        SignedOut(:final reason) => SignedOut(reason, f),
        final other => other,
      });
    }
  }

  Future<void> _signInWith(AuthSession session) async {
    final store = _store, service = _service, gateway = _gateway;
    try {
      await store.write(session.json);
    } on SecretStorageException {
      await gateway.signOutLocal();
      throw const SecureStorageUnavailable();
    }
    _set(_signedIn(await service.loadOrFetch(session)));
  }

  /// Ime je možda u međuvremenu sačuvano na drugom uređaju.
  Future<void> _refetchName(AuthSession session) async {
    try {
      final account = await _service.loadOrFetch(session);
      if (account.hasName && state is NeedsName) _set(SignedIn(account));
    } on AuthFailure {
      // Ostaje korak sa imenom.
    }
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

  /// "Promeni e-poštu" i "Nazad": nazad na korak sa e-poštom.
  void changeEmail() => state = const SignedOut();

  /// Posle čekanja kontroler je možda već uklonjen (test, odjava).
  void _set(AuthState s) {
    if (ref.mounted) state = s;
  }

  AuthState _signedIn(Account a) => a.hasName ? SignedIn(a) : NeedsName(a);

  bool get _hasAccount => state is SignedIn || state is NeedsName;

  Future<void> _onSessionChanged(AuthSession? session) async {
    if (session == null || !_hasAccount) return;
    final gateway = _gateway;
    try {
      await _store.write(session.json);
    } on SecretStorageException {
      await _lockSession(gateway);
    }
  }

  Future<void> _lockSession(AuthGateway gateway) async {
    _set(const SignedOut(SignOutReason.storageUnavailable));
    await gateway.signOutLocal();
  }

  /// "Odjavi se": briše se samo sesija. Keš, izmene koje čekaju, AI
  /// ključevi, tema i pauze modela ostaju (FR-023, FR-025); slanje staje
  /// jer nalog više nije aktivan.
  Future<void> signOut() async {
    final store = _store, gateway = _gateway;
    await store.clear();
    await gateway.signOutLocal();
    _set(const SignedOut());
  }

  /// "Obriši nalog" (samo uz mrežu). Baca [DeleteFailure]; tada se na
  /// uređaju ništa ne briše i osoba ostaje prijavljena. Istekao token se
  /// jednom obnavlja.
  Future<void> deleteAccount() async {
    final account = switch (state) {
      SignedIn(:final account) || NeedsName(:final account) => account,
      _ => null,
    };
    if (account == null) return;
    final store = _store, gateway = _gateway, service = _service;
    try {
      await service.deleteAccount(account);
    } on DeleteUnauthorized {
      try {
        await store.write((await gateway.refresh()).json);
      } on AuthFailure {
        await sessionExpired();
        throw const DeleteUnauthorized();
      }
      await service.deleteAccount(account);
    }
    await store.clear();
    await gateway.signOutLocal();
    _set(const SignedOut(SignOutReason.accountDeleted));
  }

  /// Sesija ne može da se obnovi (opozvana, istekla): nazad na prijavu sa
  /// "Sesija je istekla…"; keš i izmene koje čekaju ostaju za ponovnu
  /// prijavu (FR-008). Ako je nalog obrisan na drugom uređaju, briše se i
  /// njegov keš na ovom.
  Future<void> sessionExpired({bool accountGone = false}) async {
    final userId = switch (state) {
      SignedIn(:final account) || NeedsName(:final account) => account.userId,
      _ => null,
    };
    final store = _store, gateway = _gateway, service = _service;
    await store.clear();
    await gateway.signOutLocal();
    _set(const SignedOut(SignOutReason.sessionExpired));
    if (accountGone && userId != null) await service.wipeLocal(userId);
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
