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
  /// Polje za štikliranje.
  static const double checkbox = 8;

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
