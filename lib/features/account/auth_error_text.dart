import 'package:flutter/foundation.dart';

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
  SecureStorageUnavailable() => storageUnavailableText,
  NoAccount() => '$noAccountTitle $noAccountText',
  AlreadyRegistered() => alreadyRegisteredTitle,
  LinkExpired() => linkExpiredText,
};

/// "Prijava" sa nepoznatom adresom (kanvas: naslov i tekst napomene).
const noAccountTitle = 'Ne postoji nalog sa ovom adresom.';
const noAccountText = 'Proveri adresu ili napravi nov nalog.';

/// "Registracija" sa postojećom adresom, uz "Prijavi se umesto toga".
const alreadyRegisteredTitle = 'Već postoji nalog sa ovom adresom.';
const signInInsteadText = 'Prijavi se umesto toga';

/// Kod iz istog mejla tada više ne važi (dugme i kod su isti jednokratni
/// ključ), pa ne upućujemo na njega.
const linkExpiredText =
    'Link je istekao ili je već iskorišćen. Ako si već potvrdio/la adresu, '
    'prijavi se kodom. Ako nisi, pošalji mejl ponovo.';

const sessionExpiredText = 'Sesija je istekla. Prijavi se ponovo.';
const accountDeletedText = 'Nalog je obrisan.';
String get storageUnavailableText =>
    defaultTargetPlatform == TargetPlatform.linux
    ? 'Bezbedno skladište sesije nije dostupno. Proveri da li je sistemski keyring pokrenut i otključan, pa pokušaj ponovo.'
    : 'Funkcija nije dostupna na ovom uređaju.';

/// Poruka za neuspelo brisanje naloga.
String deleteErrorText(DeleteFailure f) => switch (f) {
  DeleteOffline() => 'Nema interneta. Nalog može da se obriše samo uz vezu.',
  DeleteServerError() => 'Brisanje nije uspelo. Pokušaj ponovo.',
  DeleteUnauthorized() => sessionExpiredText,
};
