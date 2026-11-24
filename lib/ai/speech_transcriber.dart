import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

/// Govor u tekst preko servera (`voice-transcribe`, ugovor
/// `specs/027-voice-recipe-agent/contracts/voice-agent-contract.md`).
/// Aplikacija nikad nema ključ provajdera.
abstract interface class SpeechTranscriber {
  /// Vraća prepis (može biti prazan kad ništa nije izgovoreno).
  /// Baca [TranscriptionError].
  Future<String> transcribe(Uint8List audio, {required String mimeType});
}

enum TranscriptionFailure {
  /// Sesija nije važeća (401).
  unauthorized,

  /// Limit naloga je potrošen ili server je zauzet (429).
  quota,

  /// Snimak je prevelik ili nije zvuk (413, 415, 400).
  rejected,

  /// Server ili provajder trenutno ne radi (5xx, nema ključa).
  unavailable,

  /// Nema veze ili je isteklo vreme.
  network,
}

final class TranscriptionError implements Exception {
  const TranscriptionError(this.failure, {this.retryAfter});

  final TranscriptionFailure failure;
  final Duration? retryAfter;

  @override
  String toString() => 'TranscriptionError(${failure.name})';
}

/// Poruka za osobu; uvek ostaje put do kucanja.
String transcriptionErrorText(TranscriptionError e) => switch (e.failure) {
  TranscriptionFailure.unauthorized => 'Sesija je istekla. Prijavi se ponovo.',
  TranscriptionFailure.quota =>
    'Limit je trenutno potrošen. Pokušaj malo kasnije ili ukucaj tekst.',
  TranscriptionFailure.rejected =>
    'Snimak nije mogao da se obradi. Snimi kraće ili ukucaj tekst.',
  TranscriptionFailure.unavailable =>
    'Prepoznavanje govora trenutno ne radi. Ukucaj tekst.',
  TranscriptionFailure.network => 'Nema veze sa serverom. Proveri internet.',
};

/// [SpeechTranscriber] preko `functions.invoke`: Supabase klijent dodaje
/// token prijavljenog korisnika, kao za `ai-gateway` i `delete-account`.
class SupabaseSpeechTranscriber implements SpeechTranscriber {
  SupabaseSpeechTranscriber(this._client);

  final SupabaseClient _client;

  static const functionName = 'voice-transcribe';

  /// Server čeka provajdera 30 s; klijent malo duže zbog slanja snimka.
  static const timeout = Duration(seconds: 45);

  @override
  Future<String> transcribe(Uint8List audio, {required String mimeType}) async {
    try {
      final res = await _client.functions
          .invoke(
            functionName,
            body: audio,
            headers: {'Content-Type': mimeType},
          )
          .timeout(timeout);
      final data = res.data;
      final text = data is Map ? data['text'] : null;
      if (text is! String) {
        throw const TranscriptionError(TranscriptionFailure.unavailable);
      }
      return text.trim();
    } on FunctionsFetchException {
      throw const TranscriptionError(TranscriptionFailure.network);
    } on FunctionException catch (e) {
      throw _failure(e.status, e.details);
    } on TimeoutException {
      throw const TranscriptionError(TranscriptionFailure.network);
    } on SocketException {
      throw const TranscriptionError(TranscriptionFailure.network);
    } on http.ClientException {
      throw const TranscriptionError(TranscriptionFailure.network);
    }
  }
}

TranscriptionError _failure(int status, Object? details) {
  final body = details is Map ? details : const <String, Object?>{};
  final retry = body['retryAfterSeconds'];
  final retryAfter = retry is num && retry >= 0
      ? Duration(seconds: retry.ceil())
      : null;
  return switch (status) {
    401 => const TranscriptionError(TranscriptionFailure.unauthorized),
    429 => TranscriptionError(
      TranscriptionFailure.quota,
      retryAfter: retryAfter,
    ),
    400 ||
    413 ||
    415 => const TranscriptionError(TranscriptionFailure.rejected),
    _ => const TranscriptionError(TranscriptionFailure.unavailable),
  };
}

/// Bez Supabase podešavanja (prijava nije dostupna) govor ne radi.
class UnavailableSpeechTranscriber implements SpeechTranscriber {
  const UnavailableSpeechTranscriber();

  @override
  Future<String> transcribe(Uint8List audio, {required String mimeType}) =>
      throw const TranscriptionError(TranscriptionFailure.unavailable);
}
