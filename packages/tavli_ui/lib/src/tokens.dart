import 'dart:math' as math;

/// Razmaci sa platna "ekrani po uređajima".
abstract final class TavliSpacing {
  /// Između elemenata unutar kartice ili reda.
  static const double small = 8;

  /// Između kartica obroka na Početnoj (telefon).
  static const double cards = 10;

  /// Između kartica obroka i u bočnoj koloni na računaru.
  static const double cardsWide = 12;

  /// Unutar kartice i između kartica u listi.
  static const double medium = 14;

  /// Ivica ekrana i razmak između odeljaka.
  static const double large = 20;
}

/// Broj kolona u mrežama kartica.
abstract final class TavliColumns {
  /// Današnji obroci na Početnoj kada je napomena desno (računar).
  static const int meals = 2;
}

/// Radijusi iz standarda komponenti.
abstract final class TavliRadius {
  /// Polje za štikliranje (kanvas: 6).
  static const double checkbox = 6;

  /// Čip za filter.
  static const double chip = 10;

  /// Tekstualno dugme, sličica recepta, kompaktna kartica.
  static const double compact = 14;

  /// Sporedno dugme, polje za unos, red u listi, napomena.
  static const double field = 16;

  /// Glavno i sporedno dugme (iste visine i radijusa, Anja 21.11.2026).
  static const double button = 16;

  /// Kartica, plutajuće dugme, segmentno dugme.
  static const double card = 20;

  /// Dijalog i donji list.
  static const double sheet = 24;
}

/// Najveće širine za sadržaj koji ne treba da se razvuče preko celog ekrana.
abstract final class TavliWidth {
  /// Dijalog.
  static const double dialog = 420;

  /// Veći dijalog sa listom ili mrežom za izbor (npr. omiljeni recepti na
  /// računaru).
  static const double panel = 680;

  /// Poruka praznog stanja ili greške.
  static const double message = 360;

  /// Najveća širina sadržaja ekrana sa podešavanjima na širokom ekranu.
  static const double page = 880;

  /// Lista i detalj (Nabavka na računaru): detalj desno je najviše ove
  /// širine i najviše trećina sadržaja.
  static const double detail = 300;

  /// Širina bočne kolone pored glavnog sadržaja (detalj, „Na umu“ i
  /// „Sutra“ na Početnoj): [detail], a najviše trećina [available].
  static double side(double available) => math.min(detail, available / 3);

  /// Najveća širina teksta i formi u jednoj koloni (podešavanje i pregled
  /// plana, recept), da redovi ne budu predugi na širokom ekranu.
  static const double readable = 720;

  /// Najmanja širina sadržaja od koje lista dobija detalj desno; uže od
  /// toga detalj se otvara kao donji list.
  static const double listDetail = 840;

  /// Najmanja širina sadržaja od koje Plan na računaru prikazuje nedelju
  /// kao mrežu od sedam kolona; uže od toga nedelja je kao na telefonu
  /// (traka dana i obroci izabranog dana). Na platnu (1200 px prozor)
  /// sadržaj je oko 920 px; ispod 840 kolone su uske za naziv jela i reči
  /// bi se lomile.
  static const double weekGrid = 840;
}
