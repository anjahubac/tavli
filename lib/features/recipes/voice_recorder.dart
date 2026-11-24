import 'dart:typed_data';

// Implementacija po platformi: fajlovi (dart:io) ili blob u pregledaču.
export 'voice_recorder_io.dart'
    if (dart.library.js_interop) 'voice_recorder_web.dart';

/// Snimak spreman za slanje; privremeni fajl je već obrisan.
final class RecordedClip {
  const RecordedClip(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// Snimanje samo na zahtev osobe („Govori“), bez skrivenog snimanja
/// (spec 027 FR-101, ugovor pravilo 7).
abstract interface class VoiceRecorder {
  /// Najduže trajanje snimka za izabrani format.
  Duration get maxDuration;

  /// false kad dozvola za mikrofon nije data; tada ništa ne snima.
  Future<bool> start();

  /// Zaustavlja snimanje i vraća snimak (null ako nije snimalo).
  Future<RecordedClip?> stop();

  /// Odbacuje snimanje i briše privremeni fajl.
  Future<void> cancel();

  Future<void> dispose();
}
