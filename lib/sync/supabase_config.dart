/// Konfigurasi cloud — dibaca dari `--dart-define` saat build.
/// TIDAK ADA kredensial yang di-hardcode di sini: tanpa define, semua nilai
/// kosong dan aplikasi berjalan 100% lokal (offline-first).
///
/// Cara mengisi (setelah user memberi kredensial via Secure Vault):
/// ```sh
/// flutter build apk --debug \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon-key>
/// ```
/// Untuk backup Google Sheets (opsional, manual):
/// ```sh
///   --dart-define=SHEETS_WEBAPP_URL=<url-apps-script-web-app>
/// ```
/// JANGAN menulis URL/key asli ke file ini atau ke file lain di repo.
class CloudConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// URL Web App Apps Script untuk backup Google Sheets (opsional).
  static const String sheetsWebAppUrl = String.fromEnvironment(
    'SHEETS_WEBAPP_URL',
    defaultValue: '',
  );

  /// Supabase aktif hanya bila URL + anon key terisi dan bukan placeholder.
  static bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('<') &&
        !supabaseAnonKey.contains('<');
  }

  static bool get isSheetsConfigured {
    return sheetsWebAppUrl.isNotEmpty &&
        sheetsWebAppUrl.startsWith('https://') &&
        !sheetsWebAppUrl.contains('<');
  }
}
