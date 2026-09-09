import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'supabase_service.dart';

class PlatformOperationsService {
  Uri _uri(String path) => Uri.parse('${AppConfig.backendBaseUrl}/api/platform$path');
  Map<String,String> get _headers {
    final token = SupabaseService.isReady ? SupabaseService.client.auth.currentSession?.accessToken : null;
    if (token == null) throw StateError('Sign in required');
    return {'Content-Type':'application/json', 'Authorization':'Bearer $token'};
  }
  Future<dynamic> _get(String path) async { final r=await http.get(_uri(path),headers:_headers); if(r.statusCode>=300) throw Exception(r.body); return jsonDecode(r.body); }
  Future<dynamic> _post(String path, Map<String,dynamic> body) async { final r=await http.post(_uri(path),headers:_headers,body:jsonEncode(body)); if(r.statusCode>=300) throw Exception(r.body); return jsonDecode(r.body); }
  Future<dynamic> _put(String path, Map<String,dynamic> body) async { final r=await http.put(_uri(path),headers:_headers,body:jsonEncode(body)); if(r.statusCode>=300) throw Exception(r.body); return jsonDecode(r.body); }
  Future<void> report({required String targetType,required String targetId,required String reason,String? description}) async { await _post('/moderation/report',{'targetType':targetType,'targetId':targetId,'reason':reason,'description':description}); }
  Future<void> appeal({required String caseId,required String reason}) async { await _post('/moderation/appeal',{'caseId':caseId,'reason':reason}); }
  Future<List<Map<String,dynamic>>> notifications() async => ((await _get('/notifications'))['data'] as List).cast<Map<String,dynamic>>();
  Future<void> markNotificationRead(String id) async { await _post('/notifications/$id/read',{}); }
  Future<Map<String,dynamic>> analytics({int days=30}) async => (await _get('/analytics?days=$days')) as Map<String,dynamic>;
  Future<void> analyticsEvent({required String eventName,String? objectType,String? objectId,num? value,Map<String,dynamic>? properties,String? sessionId}) async { await _post('/analytics/events',{'eventName':eventName,'objectType':objectType,'objectId':objectId,'value':value,'properties':properties??{},'sessionId':sessionId}); }
  Future<void> recommendationFeedback({required String objectType,required String objectId,required String signal,num weight=1,String? sessionId}) async { await _post('/recommendation/feedback',{'objectType':objectType,'objectId':objectId,'signal':signal,'weight':weight,'sessionId':sessionId}); }
  Future<void> registerSession({String deviceLabel='FUSKAMO mobile',String platform='android'}) async { await _post('/security/sessions',{'deviceLabel':deviceLabel,'platform':platform}); }
  Future<List<Map<String,dynamic>>> sessions() async => ((await _get('/security/sessions'))['data'] as List).cast<Map<String,dynamic>>();
  Future<void> revokeSession(String id) async { await _post('/security/sessions/$id/revoke',{}); }
  Future<List<String>> syncOperations(List<Map<String,dynamic>> operations) async => ((await _post('/offline/sync', {'operations': operations}))['applied'] as List).map((e)=>e.toString()).toList();
  Future<Map<String,dynamic>> securitySettings() async => (await _get('/security/settings'))['data'] as Map<String,dynamic>;
  Future<Map<String,dynamic>> updateSecuritySettings(Map<String,dynamic> values) async => (await _put('/security/settings',values))['data'] as Map<String,dynamic>;
}
