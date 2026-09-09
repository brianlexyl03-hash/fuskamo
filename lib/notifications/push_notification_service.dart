import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Real FCM wiring: requests permission, reads the device token, keeps it
/// attached to the signed-in user in Supabase (table `device_tokens` —
/// see database/migrations/006_device_tokens.sql), and listens for
/// foreground messages.
///
/// Requires a Firebase project of your own before this compiles/runs on
/// device — see docs/push-notifications-setup.md for the exact steps
/// (there's no way around creating that project yourself; nobody can hand
/// you working Firebase credentials for an app they don't own).
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance = PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  String? _lastToken;

  /// Call once at startup, after Firebase.initializeApp() (see main.dart).
  /// Safe to call even if Firebase isn't set up — failures are caught and
  /// logged rather than crashing app boot.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushNotificationService: notification permission denied');
        return;
      }

      _lastToken = await _messaging.getToken();
      await registerTokenForCurrentUser();

      _messaging.onTokenRefresh.listen((newToken) {
        _lastToken = newToken;
        registerTokenForCurrentUser();
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _initialized = true;
    } catch (e) {
      // Most likely cause: Firebase isn't configured for this platform yet
      // (missing google-services.json / GoogleService-Info.plist). Fail
      // soft so the rest of the app keeps working.
      debugPrint('PushNotificationService init failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Push received in foreground: ${message.notification?.title}');
    // Hook point for an in-app banner/toast if you want one later —
    // deliberately not forcing a UI dependency into this service.
  }

  /// Upserts (user_id, token) into `device_tokens` so the backend can
  /// target this device. No-ops if there's no token yet or nobody is
  /// signed in — called again automatically once sign-in happens (see
  /// AuthProvider) and on token refresh.
  Future<void> registerTokenForCurrentUser() async {
    if (_lastToken == null || !SupabaseService.isReady) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    // Respect the Notification Preferences toggle (see profile_screen.dart)
    // — without this check, turning "push" off in settings would update a
    // database row nothing ever reads, and pushes would keep arriving anyway.
    try {
      final prefRows = await SupabaseService.client
          .from('notification_preferences')
          .select('push_enabled')
          .eq('user_id', userId)
          .limit(1);
      final pushEnabled =
          (prefRows as List).isNotEmpty ? (prefRows.first['push_enabled'] as bool? ?? true) : true;
      if (!pushEnabled) {
        await unregisterToken();
        return;
      }
    } catch (e) {
      // Preference lookup failing shouldn't block registration — default
      // to on, same as the database column's own default.
      debugPrint('Could not read notification preferences, defaulting to push-enabled: $e');
    }

    try {
      await SupabaseService.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': _lastToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('Failed to register push token: $e');
    }
  }

  /// Call on sign-out so a shared/reset device doesn't keep receiving a
  /// previous user's notifications.
  Future<void> unregisterToken() async {
    if (_lastToken == null || !SupabaseService.isReady) return;
    try {
      await SupabaseService.client.from('device_tokens').delete().eq('token', _lastToken!);
    } catch (e) {
      debugPrint('Failed to unregister push token: $e');
    }
  }
}

/// Must be a top-level function (not a class method) — this is FCM's
/// requirement for background message handling. Register it in main.dart
/// with FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage)
/// before runApp().
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  debugPrint('Push received in background: ${message.notification?.title}');
}
