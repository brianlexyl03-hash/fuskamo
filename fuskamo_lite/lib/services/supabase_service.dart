import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Thin wrapper around Supabase init/access. Every other service goes
/// through this instead of touching Supabase.instance directly, so there's
/// one place to swap backends later if ever needed.
class SupabaseService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    if (!AppConfig.isSupabaseConfigured) {
      // Not configured yet — screens fall back to empty states. See README.
      return;
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static bool get isReady => _initialized;

  static SupabaseClient get client => Supabase.instance.client;
}
