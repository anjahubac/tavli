/// Zamena za `dart:io` `SocketException` u pregledaču (nikad se ne baca).
class SocketException implements Exception {
  const SocketException(this.message);

  final String message;

  @override
  String toString() => 'SocketException: $message';
}
