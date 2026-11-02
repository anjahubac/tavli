/// Adresa i javni (anon) ključ Supabase projekta iz
/// `--dart-define-from-file=secrets.json`. Bez njih prijava nije dostupna.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String url;
  final String anonKey;

  bool get isConfigured => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  /// Bez ključa, da ne završi u logu.
  @override
  String toString() => 'SupabaseConfig($url)';
}
