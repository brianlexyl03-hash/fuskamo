/// Mirrors the `notifications` table in Supabase (see
/// database/migrations/005_notifications.sql). Rows are created server-side
/// only (mpesa/admin flows via the backend's service-role client) — the
/// Flutter app only ever reads its own and marks them read.
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String? type;
  final String? deepLink;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type,
    this.deepLink,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      type: json['type'] as String?,
      deepLink: json['deep_link'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
