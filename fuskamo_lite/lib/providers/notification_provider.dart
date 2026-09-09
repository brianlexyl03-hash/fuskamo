import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

/// Attached to the signed-in user id via a ChangeNotifierProxyProvider in
/// app.dart (see AuthProvider) — re-subscribes automatically on sign-in /
/// sign-out so it's never showing a leftover stream from a previous user.
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repo = NotificationRepository();
  StreamSubscription<List<AppNotification>>? _sub;
  String? _userId;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  void attachUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _sub?.cancel();
    _notifications = [];

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _repo.streamForUser(userId).listen((rows) {
      _notifications = rows;
      notifyListeners();
    });
  }

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    // Optimistic local update — the Realtime stream will confirm shortly.
    _notifications = _notifications
        .map((n) => n.id == id
            ? AppNotification(id: n.id, title: n.title, body: n.body, type: n.type, deepLink: n.deepLink, read: true, createdAt: n.createdAt)
            : n)
        .toList();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    if (_userId == null) return;
    await _repo.markAllRead(_userId!);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
