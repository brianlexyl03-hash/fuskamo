import 'platform_operations_service.dart';
class AnalyticsService {
  final PlatformOperationsService _api=PlatformOperationsService();
  Future<void> track(String event,{String? objectType,String? objectId,num value=1,Map<String,dynamic>? properties,String? sessionId}) async { try { await _api.analyticsEvent(eventName:event,objectType:objectType,objectId:objectId,value:value,properties:properties,sessionId:sessionId); } catch (_) {} }
  Future<Map<String,dynamic>> summary({int days=30})=>_api.analytics(days:days);
}
