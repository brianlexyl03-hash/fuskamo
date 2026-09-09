import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'network/connectivity_service.dart';
import 'notifications/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'services/offline_sync_service.dart';
import 'services/platform_operations_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await SupabaseService.init();
  await ConnectivityService.instance.init();
  if (SupabaseService.isReady && SupabaseService.client.auth.currentUser != null) {
    try { await PlatformOperationsService().registerSession(); } catch (_) {}
    try { await OfflineSyncService().flush(); } catch (_) {}
  }

  // Firebase is optional at this stage: no google-services.json /
  // GoogleService-Info.plist means this throws, and the app should still
  // run without push notifications rather than fail to boot — see
  // docs/push-notifications-setup.md for adding real Firebase config.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('Firebase not configured yet — push notifications disabled: $e');
  }

  runApp(const FuskamoApp());
}
