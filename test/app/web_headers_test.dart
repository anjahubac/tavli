import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Direktive iz CSP zaglavlja u `web/_headers`, npr. `connect-src` → izvori.
Map<String, List<String>> _csp() {
  final line = File('web/_headers')
      .readAsLinesSync()
      .map((l) => l.trim())
      .firstWhere((l) => l.startsWith('Content-Security-Policy:'));
  final policy = line.substring('Content-Security-Policy:'.length);
  return {
    for (final part in policy.split(';'))
      if (part.trim().isNotEmpty)
        part.trim().split(RegExp(r'\s+')).first: part
            .trim()
            .split(RegExp(r'\s+'))
            .skip(1)
            .toList(),
  };
}

void main() {
  test('web reads picked files through blob URLs', () {
    // file_selector daje XFile koji readAsBytes čita XHR-om sa blob: URL-a;
    // bez blob: u connect-src dodavanje knjige i slika na webu ne radi.
    expect(_csp()['connect-src'], contains('blob:'));
  });

  test('web connects only to its own origin, blob URLs and Supabase', () {
    expect(_csp()['connect-src'], [
      "'self'",
      'blob:',
      'https://*.supabase.co',
      'wss://*.supabase.co',
    ]);
  });
}
