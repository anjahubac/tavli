import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/account/supabase_config.dart';

void main() {
  test('bez vrednosti iz secrets.json nije podešeno', () {
    // Testovi se pokreću bez --dart-define-from-file.
    expect(SupabaseConfig.fromEnvironment().isConfigured, isFalse);
    expect(
      const SupabaseConfig(url: 'http://x', anonKey: '').isConfigured,
      isFalse,
    );
    expect(const SupabaseConfig(url: ' ', anonKey: 'k').isConfigured, isFalse);
  });

  test('podešeno kad postoje i adresa i ključ', () {
    const c = SupabaseConfig(url: 'http://127.0.0.1:1', anonKey: 'fake-anon');
    expect(c.isConfigured, isTrue);
  });

  test('toString nikad ne sadrži ključ', () {
    const c = SupabaseConfig(
      url: 'http://127.0.0.1:1',
      anonKey: 'fake-anon-key-value',
    );
    expect(c.toString(), isNot(contains('fake-anon-key-value')));
    expect(c.toString(), contains('127.0.0.1'));
  });
}
