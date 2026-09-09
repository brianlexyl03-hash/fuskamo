import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place the app reads runtime configuration from.
/// Values come from the .env file (see .env.example at the repo root —
/// copy it to .env and fill in your real Supabase + backend details).
class AppConfig {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // A clean checkout must still boot before local secrets are supplied.
      // SupabaseService remains disabled until real credentials are present.
    }
    _loaded = true;
  }

  // Supabase — direct, anon-key, RLS-constrained access.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // Custom backend (see /backend) — M-Pesa, AI, privileged operations.
  static String get backendBaseUrl =>
      dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:8080';
  static String get backendApiKey => dotenv.env['BACKEND_API_KEY'] ?? '';
  static bool get isBackendConfigured => backendApiKey.isNotEmpty;

  // Admin review no longer lives inside this app at all — see
  // admin-web/README.md and docs/admin-access.md. There is deliberately no
  // admin config here anymore: a shared key baked into any Flutter build
  // (public or "private") is exactly the risk-of-decompilation problem
  // the RBAC rework removed. Every administrator now has their own
  // Supabase Auth account, managed entirely through admin-web/.
}
