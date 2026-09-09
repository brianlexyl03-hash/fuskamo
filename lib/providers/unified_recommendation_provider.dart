import 'package:flutter/foundation.dart';
import '../models/unified_recommendation_model.dart';
import '../services/unified_recommendation_service.dart';

class UnifiedRecommendationProvider extends ChangeNotifier {
  final UnifiedRecommendationService _service = UnifiedRecommendationService();
  List<UnifiedRecommendation> items = const [];
  bool loading = false;
  String? error;

  Future<void> load({int limit = 30}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await _service.feed(limit: limit);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> feedback({required String objectType,required String objectId,required String signal,num weight=1}) async { try { await _service.recommendationFeedback(objectType:objectType,objectId:objectId,signal:signal,weight:weight); } catch (_) {} }

  Future<void> event({required String objectType, required String objectId, required String eventType, String? subjectUserId}) async {
    try {
      await _service.recordEvent(objectType: objectType, objectId: objectId, eventType: eventType, subjectUserId: subjectUserId);
    } catch (_) {
      // Recommendation telemetry is intentionally non-blocking for UX.
    }
  }
}
