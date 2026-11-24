import 'dart:io';

import 'package:win32/win32.dart' show WindowsException;

/// Kod greške bezbednog skladišta koja ne dolazi preko platformskog kanala:
/// Windows implementacija (FFI) baca [WindowsException], a fajl varijante
/// [FileSystemException]. Poruke (putanje) se ne prenose, samo kod.
String? nativeSecretStorageErrorCode(Object error) => switch (error) {
  WindowsException(:final hr) =>
    'windows:0x${(hr & 0xFFFFFFFF).toRadixString(16)}',
  FileSystemException(:final osError) =>
    'fs:${osError?.errorCode ?? 'unknown'}',
  _ => null,
};
