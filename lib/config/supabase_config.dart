/// ─────────────────────────────────────────────────────────
/// SUPABASE CONFIG — FILL THESE IN AFTER YOU CREATE YOUR PROJECT
/// Get both values from: Supabase Dashboard → Project Settings → API
/// Do NOT commit real values here — load them from .env instead (see
/// AppConfig.load() in app_config.dart, which reads flutter_dotenv).
/// ─────────────────────────────────────────────────────────
class SupabaseConfig {
  static const String urlEnvKey = 'SUPABASE_URL';
  static const String anonKeyEnvKey = 'SUPABASE_ANON_KEY';
  static const String playerVideosBucket = 'player-videos';
}
