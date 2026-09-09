import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/unified_recommendation_model.dart';
import 'supabase_service.dart';

class UnifiedRecommendationService {
  Uri _uri(String path) => Uri.parse('${AppConfig.backendBaseUrl}/api$path');

  Future<Map<String, String>> _headers() async {
    final token = SupabaseService.isReady ? SupabaseService.client.auth.currentSession?.accessToken : null;
    if (token == null) throw StateError('Sign in to use recommendations.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (AppConfig.backendApiKey.isNotEmpty) 'x-api-key': AppConfig.backendApiKey,
    };
  }

  Future<List<UnifiedRecommendation>> feed({int limit = 30}) async {
    final res = await http.get(_uri('/recommendations/feed?limit=$limit'), headers: await _headers());
    if (res.statusCode != 200) throw Exception('Recommendation feed failed: ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List? ?? [])
        .map((e) => UnifiedRecommendation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> recordEvent({
    required String objectType,
    required String objectId,
    required String eventType,
    String? subjectUserId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await http.post(
      _uri('/recommendations/events'),
      headers: await _headers(),
      body: jsonEncode({
        'objectType': objectType,
        'objectId': objectId,
        'eventType': eventType,
        if (subjectUserId != null) 'subjectUserId': subjectUserId,
        if (sessionId != null) 'sessionId': sessionId,
        if (metadata != null) 'metadata': metadata,
      }),
    );
    if (res.statusCode != 201) throw Exception('Recommendation event failed: ${res.body}');
  }

  Future<void> recommendationFeedback({required String objectType,required String objectId,required String signal,num weight=1,String? sessionId}) async {
    final res=await http.post(_uri('/platform/recommendation/feedback'),headers:await _headers(),body:jsonEncode({'objectType':objectType,'objectId':objectId,'signal':signal,'weight':weight,'sessionId':sessionId}));
    if(res.statusCode>=300) throw Exception('Recommendation feedback failed: ${res.body}');
  }
}
