import '../../account/account_api.dart';
import '../../account/auth_gateway.dart';

/// Poruka za korisnika za neuspelu prijavu ili obnovu sesije.
String authErrorText(AuthFailure f) => switch (f) {
  WrongCode() => 'Kod nije ispravan. Proveri poruku i pokušaj ponovo.',
  CodeExpired() => 'Kod je istekao. Pošalji novi kod.',
  RateLimited() => 'Previše pokušaja. Sačekaj malo pa pokušaj ponovo.',
  Offline() => 'Nema interneta. Za prijavu je potrebna veza.',
  Unavailable() => 'Prijava trenutno nije dostupna.',
  SessionRevoked() || AccountGone() => sessionExpiredText,
};

const sessionExpiredText = 'Sesija je istekla. Prijavi se ponovo.';
const accountDeletedText = 'Nalog je obrisan.';

/// Poruka za neuspelo brisanje naloga.
String deleteErrorText(DeleteFailure f) => switch (f) {
  DeleteOffline() => 'Nema interneta. Nalog može da se obriše samo uz vezu.',
  DeleteServerError() => 'Brisanje nije uspelo. Pokušaj ponovo.',
  DeleteUnauthorized() => sessionExpiredText,
};
