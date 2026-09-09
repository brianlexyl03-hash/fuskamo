import '../models/notification_model.dart';
import 'supabase_service.dart';

/// Notifications are just rows the Flutter app reads directly from
/// Supabase and subscribes to live via Realtime — no socket server
/// involved (see backend/src/repositories/notificationRepository.js file
/// comment, which documents the same design from the other side: the
/// backend only ever *writes* these rows, via mpesa/admin flows).
class NotificationService {
  Future<List<AppNotification>> fetchForUser(String userId) async {
    if (!SupabaseService.isReady) return [];
    final rows = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Realtime stream of this user's notifications — fires again on every
  /// insert/update, e.g. the moment a boost payment completes and the
  /// backend writes a "Your submission is now featured" row.
  Stream<List<AppNotification>> streamForUser(String userId) {
    return SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => AppNotification.fromJson(r)).toList());
  }

  Future<void> markRead(String id) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', userId)
        .eq('read', false);
  }

  /// Row defaults to all-true (see 005_notifications.sql) — a user who's
  /// never touched their preferences gets one back with sensible defaults
  /// rather than null.
  Future<Map<String, bool>> getPreferences(String userId) async {
    if (!SupabaseService.isReady) return {'push': true, 'email': true, 'sms': true};
    final rows = await SupabaseService.client
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .limit(1);
    final row = (rows as List).isNotEmpty ? rows.first as Map<String, dynamic> : null;
    return {
      'push': row?['push_enabled'] as bool? ?? true,
      'email': row?['email_enabled'] as bool? ?? true,
      'sms': row?['sms_enabled'] as bool? ?? true,
    };
  }

  Future<void> updatePreferences(
    String userId, {
    required bool push,
    required bool email,
    required bool sms,
  }) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.from('notification_preferences').upsert({
      'user_id': userId,
      'push_enabled': push,
      'email_enabled': email,
      'sms_enabled': sms,
    });
  }
}
