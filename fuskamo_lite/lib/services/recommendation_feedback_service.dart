import 'platform_operations_service.dart';
class RecommendationFeedbackService {
  final _api=PlatformOperationsService();
  Future<void> signal({required String objectType,required String objectId,required String signal,num weight=1,String? sessionId}) async { try { await _api.recommendationFeedback(objectType:objectType,objectId:objectId,signal:signal,weight:weight,sessionId:sessionId); } catch (_) {} }
}
