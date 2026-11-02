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
