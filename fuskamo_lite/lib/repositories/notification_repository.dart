import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationRepository {
  final NotificationService _service = NotificationService();

  Future<List<AppNotification>> getForUser(String userId) => _service.fetchForUser(userId);

  Stream<List<AppNotification>> streamForUser(String userId) => _service.streamForUser(userId);

  Future<void> markRead(String id) => _service.markRead(id);

  Future<void> markAllRead(String userId) => _service.markAllRead(userId);

  Future<Map<String, bool>> getPreferences(String userId) => _service.getPreferences(userId);

  Future<void> updatePreferences(String userId, {required bool push, required bool email, required bool sms}) =>
      _service.updatePreferences(userId, push: push, email: email, sms: sms);
}
