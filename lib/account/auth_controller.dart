import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/key_store.dart';
import '../domain/account.dart';
import '../providers.dart';
import '../sync/sync_engine.dart';
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
  const NeedsName(this.account, {this.membershipVerified = true});

  final Account account;
  final bool membershipVerified;
}

/// Ima ime, ali još nije izabrao domaćinstvo: daje naziv ličnom
/// domaćinstvu ili se pridružuje drugom (obavezan korak posle imena).
class NeedsHousehold extends AuthState {
  const NeedsHousehold(this.account, {this.membershipVerified = true});

  final Account account;
  final bool membershipVerified;
}

class SignedIn extends AuthState {
  const SignedIn(this.account, {this.membershipVerified = true});

  final Account account;
  final bool membershipVerified;
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
    ref.onDispose(() {
      unawaited(_sessions?.cancel());
      _membershipRetry?.cancel();
    });
    return const Starting();
  }

  /// Proverava članstvo pre pokretanja sync-a. Keš radi i bez mreže.
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
    try {
      final session = await gateway.restore(json);
      await store.write(session.json);
      final fresh = await service.loadOrFetch(session, allowOffline: false);
      if (account != null) _noticeIfRemoved(account, fresh);
      _set(_signedIn(fresh));
    } on SecretStorageException {
      await _lockSession(gateway);
    } on AuthFailure catch (f) {
      if (account == null) {
        _set(const SignedOut());
      } else if (f is Offline || f is Unavailable) {
        _useOfflineCache(account);
      } else {
        _set(NeedsName(account));
        await sessionExpired(accountGone: f is AccountGone);
      }
    }
  }

  Timer? _membershipRetry;

  void _useOfflineCache(Account account) {
    _set(_signedIn(account, membershipVerified: false));
    _retryMembership();
  }

  void _retryMembership({SyncEngine? deniedBy}) {
    if (!ref.mounted || !_hasAccount) return;
    _membershipRetry?.cancel();
    _membershipRetry = Timer(const Duration(seconds: 5), () {
      unawaited(
        deniedBy == null ? restoreSession() : recheckMembership(deniedBy),
      );
    });
  }

  /// Obnavlja sačuvanu sesiju (start, povratak u aplikaciju). Bez mreže
  /// ostaje prijavljen; odbijena obnova vraća na prijavu.
  Future<void> restoreSession({SyncEngine? sync}) => _restore(sync);

  Future<void> _restore(SyncEngine? sync, {bool afterDenial = false}) async {
    if (!ref.mounted ||
        !_hasAccount ||
        _restoringSession ||
        _checkingMembership) {
      return;
    }
    _restoringSession = true;
    try {
      await _restoreSession(sync, afterDenial: afterDenial);
    } finally {
      _restoringSession = false;
    }
    final recheck = _pendingRecheck;
    _pendingRecheck = null;
    if (recheck != null) await recheckMembership(recheck);
  }

  /// The server denied a write (RLS 42501, Storage 403): the user may have
  /// been removed from the household. When a check is already running, it may
  /// have read membership before the removal, so one more check runs after it.
  Future<void> recheckMembership(SyncEngine sync) async {
    if (!ref.mounted || !_hasAccount) return;
    if (_restoringSession) {
      _pendingRecheck = sync;
      return;
    }
    if (_checkingMembership) {
      _retryMembership(deniedBy: sync);
      return;
    }
    await _restore(sync, afterDenial: true);
  }

  SyncEngine? _pendingRecheck;

  var _restoringSession = false;

  Future<void> _restoreSession(
    SyncEngine? sync, {
    required bool afterDenial,
  }) async {
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
      if (!ref.mounted) return;
      await store.write(session.json);
      if (!ref.mounted || _checkingMembership) return;
      if (state is NeedsName || state is NeedsHousehold) {
        await _refetchOnboarding(session);
        return;
      }
      final initial = state;
      if (initial is! SignedIn || initial.account.userId != session.userId) {
        return;
      }
      final service = _service;
      _checkingMembership = true;
      try {
        Future<void> reconcile() async {
          final account = await service.refreshMembership(initial.account);
          if (!ref.mounted || !identical(state, initial)) return;
          if (account.householdId != initial.account.householdId) {
            sync?.stop();
            _pendingRecheck = null;
          }
          _noticeIfRemoved(initial.account, account);
          _membershipRetry?.cancel();
          if (!initial.membershipVerified ||
              account.householdId != initial.account.householdId ||
              account.role != initial.account.role ||
              account.householdName != initial.account.householdName) {
            _set(_signedIn(account));
          }
        }

        await (sync == null
            ? reconcile()
            : sync.reconcileMembership(reconcile));
      } finally {
        _checkingMembership = false;
      }
    } on SecretStorageException {
      await _lockSession(gateway);
    } on AuthFailure catch (f) {
      if (f is Offline || f is Unavailable) {
        if (afterDenial) {
          _retryMembership(deniedBy: sync);
        } else {
          _retryIfUnverified();
        }
      } else if (ref.mounted) {
        await sessionExpired(accountGone: f is AccountGone);
      }
    }
  }

  void _retryIfUnverified() {
    if (!ref.mounted) return;
    if (state
        case SignedIn(membershipVerified: false) ||
            NeedsName(membershipVerified: false) ||
            NeedsHousehold(membershipVerified: false)) {
      _retryMembership();
    }
  }

  var _checkingMembership = false;

  Future<HouseholdJoinResult> confirmHouseholdJoin({
    required String token,
    required String expectedSourceHouseholdId,
    required JoinRecipeChoice recipeChoice,
    required bool acknowledgeSourceDeletion,
    required String operationId,
    required SyncEngine? sync,
    bool proceedWithoutPendingWrites = false,
  }) async {
    final initial = state;
    final initialAccount = switch (initial) {
      SignedIn(membershipVerified: true, :final account) ||
      NeedsHousehold(membershipVerified: true, :final account) => account,
      _ => null,
    };
    if (initialAccount == null || _checkingMembership || _restoringSession) {
      return const HouseholdJoinResult(status: 'unavailable');
    }
    if (initialAccount.householdId != expectedSourceHouseholdId) {
      return const HouseholdJoinResult(status: 'stale_source');
    }
    final service = _service;
    _checkingMembership = true;
    try {
      if (!proceedWithoutPendingWrites &&
          await service.hasPendingHouseholdWrites(initialAccount.userId)) {
        sync?.kick();
        return const HouseholdJoinResult(status: 'pending_sync');
      }
      Future<HouseholdJoinResult> confirm() async {
        if (!ref.mounted || !identical(state, initial)) {
          return const HouseholdJoinResult(status: 'unavailable');
        }
        final result = await service.confirmHouseholdJoin(
          account: initialAccount,
          token: token,
          recipeChoice: recipeChoice,
          acknowledgeSourceDeletion: acknowledgeSourceDeletion,
          operationId: operationId,
          proceedWithoutPendingWrites: proceedWithoutPendingWrites,
        );
        if (result.account != null &&
            ref.mounted &&
            identical(state, initial)) {
          final account = await service.cached(initialAccount.userId);
          if (account != null && ref.mounted && identical(state, initial)) {
            if (account.householdId != initialAccount.householdId) {
              sync?.stop();
              _membershipRetry?.cancel();
            }
            _set(_signedIn(account));
          }
        }
        return result;
      }

      return await (sync == null
          ? confirm()
          : sync.reconcileMembership(confirm));
    } finally {
      _checkingMembership = false;
    }
  }

  /// Naziv domaćinstva: korak "Tvoje domaćinstvo" ili "Izmeni domaćinstvo"
  /// (samo vlasnik). Baca [ArgumentError] za neispravan naziv i
  /// [AuthFailure]; stanje tada ostaje.
  Future<RenameHouseholdResult> renameHousehold(String name) async {
    final initial = state;
    final (account, verified) = switch (initial) {
      SignedIn(:final account, :final membershipVerified) ||
      NeedsHousehold(
        :final account,
        :final membershipVerified,
      ) => (account, membershipVerified),
      _ => (null, false),
    };
    if (account == null) return RenameHouseholdResult.notAllowed;
    final (result, updated) = await _service.renameHousehold(account, name);
    if (result == RenameHouseholdResult.renamed &&
        ref.mounted &&
        identical(state, initial)) {
      _set(_signedIn(updated, membershipVerified: verified));
    }
    return result;
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
    if (_hasAccount) return;
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
    try {
      _set(_signedIn(await service.loadOrFetch(session, allowOffline: false)));
    } on AuthFailure catch (failure) {
      if (failure is! Offline && failure is! Unavailable) rethrow;
      final account = await service.cached(session.userId);
      if (account == null) rethrow;
      _useOfflineCache(account);
    }
  }

  /// Ime ili domaćinstvo je možda u međuvremenu sačuvano na drugom uređaju.
  Future<void> _refetchOnboarding(AuthSession session) async {
    try {
      final account = await _service.loadOrFetch(session, allowOffline: false);
      _membershipRetry?.cancel();
      if (ref.mounted && (state is NeedsName || state is NeedsHousehold)) {
        _set(_signedIn(account));
      }
    } on Offline {
      _retryIfUnverified();
    } on Unavailable {
      _retryIfUnverified();
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
    final verified = switch (state) {
      SignedIn(:final membershipVerified) ||
      NeedsName(:final membershipVerified) => membershipVerified,
      _ => false,
    };
    _set(
      _signedIn(
        await _service.saveName(account, name),
        membershipVerified: verified,
      ),
    );
  }

  /// "Promeni e-poštu" i "Nazad": nazad na korak sa e-poštom.
  void changeEmail() => state = const SignedOut();

  /// Posle čekanja kontroler je možda već uklonjen (test, odjava).
  /// Domaćinstvo se promenilo van ovog uređaja. Sopstveni prelazak na
  /// drugom uređaju daje ulogu člana; uklanjanje (`remove_household_member`)
  /// pravi novo lično domaćinstvo sa ulogom vlasnika. Ako je osoba na
  /// drugom uređaju prešla pa postala naslednik vlasnika, obaveštenje bi
  /// bilo pogrešno; to je redak slučaj bez posebnog signala sa servera.
  void _noticeIfRemoved(Account before, Account after) {
    if (before.userId != after.userId ||
        before.householdId == after.householdId ||
        !after.isOwner) {
      return;
    }
    ref
        .read(householdRemovalNoticeProvider.notifier)
        .set(
          HouseholdRemovalNotice(
            previousHouseholdName: before.householdName,
            currentHouseholdName: after.householdName,
          ),
        );
  }

  void _set(AuthState s) {
    if (!ref.mounted) return;
    if (s is SignedOut) {
      _membershipRetry?.cancel();
      _pendingRecheck = null;
    }
    state = s;
  }

  AuthState _signedIn(Account a, {bool membershipVerified = true}) => !a.hasName
      ? NeedsName(a, membershipVerified: membershipVerified)
      : !a.householdReady
      ? NeedsHousehold(a, membershipVerified: membershipVerified)
      : SignedIn(a, membershipVerified: membershipVerified);

  bool get _hasAccount =>
      state is SignedIn || state is NeedsName || state is NeedsHousehold;

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
      SignedIn(:final account) ||
      NeedsName(:final account) ||
      NeedsHousehold(:final account) => account,
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
      SignedIn(:final account) ||
      NeedsName(:final account) ||
      NeedsHousehold(:final account) => account.userId,
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

/// Osoba je uklonjena iz domaćinstva i prebačena u novo lično domaćinstvo.
class HouseholdRemovalNotice {
  const HouseholdRemovalNotice({
    required this.previousHouseholdName,
    required this.currentHouseholdName,
  });

  final String previousHouseholdName;
  final String currentHouseholdName;
}

/// Obaveštenje o uklanjanju koje čeka da ga aplikacija prikaže. Samo u
/// memoriji: prikazuje se jednom, kada uređaj primeti promenu.
final householdRemovalNoticeProvider =
    NotifierProvider<HouseholdRemovalNotices, HouseholdRemovalNotice?>(
      HouseholdRemovalNotices.new,
    );

class HouseholdRemovalNotices extends Notifier<HouseholdRemovalNotice?> {
  @override
  HouseholdRemovalNotice? build() => null;

  void set(HouseholdRemovalNotice notice) => state = notice;

  /// Vraća obaveštenje i briše ga, da se dijalog ne otvori dvaput.
  HouseholdRemovalNotice? take() {
    final notice = state;
    state = null;
    return notice;
  }
}

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
