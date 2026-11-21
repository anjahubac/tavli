/// Razmaci sa platna "ekrani po uređajima".
abstract final class TavliSpacing {
  /// Između elemenata unutar kartice ili reda.
  static const double small = 8;

  /// Unutar kartice i između kartica u listi.
  static const double medium = 14;

  /// Ivica ekrana i razmak između odeljaka.
  static const double large = 20;
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

  /// Glavno dugme.
  static const double button = 18;

  /// Kartica, plutajuće dugme, segmentno dugme.
  static const double card = 20;

  /// Dijalog i donji list.
  static const double sheet = 24;
}

/// Najveće širine za sadržaj koji ne treba da se razvuče preko celog ekrana.
abstract final class TavliWidth {
  /// Dijalog.
  static const double dialog = 420;

  /// Poruka praznog stanja ili greške.
  static const double message = 360;

  /// Najveća širina sadržaja ekrana sa podešavanjima na širokom ekranu.
  static const double page = 880;

  /// Lista i detalj (Nabavka na računaru): detalj desno je najviše ove
  /// širine i najviše trećina sadržaja.
  static const double detail = 300;

  /// Najmanja širina sadržaja od koje lista dobija detalj desno; uže od
  /// toga detalj se otvara kao donji list.
  static const double listDetail = 840;

  /// Najmanja širina sadržaja od koje Plan na računaru prikazuje nedelju
  /// kao mrežu od sedam kolona; uže od toga nedelja je kao na telefonu
  /// (traka dana i obroci izabranog dana).
  static const double weekGrid = 640;
}
