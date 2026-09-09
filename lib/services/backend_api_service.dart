import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'supabase_service.dart';

/// Calls the custom backend (see /backend at repo root) for anything that
/// needs a secret or privileged Supabase access — M-Pesa payments, AI
/// summaries. This is deliberately separate from PlayerService/ScoutService,
/// which talk to Supabase directly for plain reads/writes RLS already
/// covers safely.
class BackendApiService {
  Uri _uri(String path) => Uri.parse('${AppConfig.backendBaseUrl}/api$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AppConfig.backendApiKey.isNotEmpty) 'x-api-key': AppConfig.backendApiKey,
      };

  /// discovery/* routes are per-user (jwtAuth on the backend, not the
  /// shared x-api-key) — they need to know WHICH scout is calling, to look
  /// up preferences and attribute engagement events. Throws if there's no
  /// signed-in session; callers (DiscoveryRepository) turn that into a
  /// plain "sign in to see your discovery feed" message for the UI.
  Map<String, String> get _authHeaders {
    final token = SupabaseService.isReady
        ? SupabaseService.client.auth.currentSession?.accessToken
        : null;
    if (token == null) {
      throw StateError('Sign in to see your personalized discovery feed.');
    }
    return {..._headers, 'Authorization': 'Bearer $token'};
  }

  /// Live country list (name + flag emoji) for the submit form's country
  /// field — see docs/api.md. Using this instead of free text keeps
  /// submissions matching the exact country names region_model.dart's
  /// Discover filtering relies on ("Kenya", not "kenya" or "Kenya ").
  Future<List<Map<String, dynamic>>> getCountries() async {
    final res = await http.get(_uri('/external/countries'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load countries: ${res.body}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Kicks off an M-Pesa STK push (PIN prompt) on the payer's phone.
  /// [phoneNumber] must be in 2547XXXXXXXX format. [amount] is in KES.
  Future<Map<String, dynamic>> initiateMpesaPayment({
    required String phoneNumber,
    required int amount,
    String? accountReference,
    String? transactionDesc,
  }) async {
    final res = await http.post(
      _uri('/mpesa/stk-push'),
      headers: _headers,
      body: jsonEncode({
        'phoneNumber': phoneNumber,
        'amount': amount,
        if (accountReference != null) 'accountReference': accountReference,
        if (transactionDesc != null) 'transactionDesc': transactionDesc,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('M-Pesa request failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Polls the backend for how an already-initiated STK push resolved.
  /// Returns the raw `data` object — callers check `data['local']['status']`
  /// which is one of 'pending' | 'completed' | 'failed'.
  Future<Map<String, dynamic>> getPaymentStatus(String checkoutRequestId) async {
    final res = await http.get(_uri('/mpesa/status/$checkoutRequestId'), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Payment status request failed: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  /// Gets a short AI-generated scouting note for a submission, useful as an
  /// optional preview shown to the submitter or to reviewers.
  Future<String> summarizePlayer({
    required String name,
    required String position,
    required int age,
    required String country,
    String? club,
    String? strengths,
  }) async {
    final res = await http.post(
      _uri('/ai/summarize-player'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'position': position,
        'age': age,
        'country': country,
        if (club != null) 'club': club,
        if (strengths != null) 'strengths': strengths,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('AI summary request failed: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['summary'] as String? ?? '';
  }

  /// Ranked players for the signed-in scout, from discoveryEngine.js's
  /// scoring/diversity pass. 404s (as a thrown Exception) when the account
  /// has no verified scout profile yet — DiscoveryRepository turns that
  /// into a "become a verified scout to unlock this" state rather than a
  /// generic error.
  Future<List<Map<String, dynamic>>> getDiscoveryFeed({int limit = 30}) async {
    final res = await http.get(
      _uri('/discovery/feed?limit=$limit'),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Discovery feed request failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Player Discovery V2: multi-stage fraud -> light rank -> deep utility ->
  /// repetition/diversity -> controlled exploration -> boost mixer.
  Future<List<Map<String, dynamic>>> getDiscoveryFeedV2({int limit = 30}) async {
    final res = await http.get(
      _uri('/discovery/v2/feed?limit=$limit'),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Discovery V2 feed request failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Logs one engagement event (view/save/contact/share) against a player,
  /// for discoveryEngine.js's 7-day engagement scoring and fraud signal.
  /// Fire-and-forget from the UI's perspective — callers shouldn't block
  /// user-visible actions on this succeeding.
  Future<void> logDiscoveryEvent({
    required String playerId,
    required String eventType,
    String? deviceId,
  }) async {
    await http.post(
      _uri('/discovery/events'),
      headers: _authHeaders,
      body: jsonEncode({
        'playerId': playerId,
        'eventType': eventType,
        if (deviceId != null) 'deviceId': deviceId,
      }),
    );
  }

  Future<void> logDiscoveryEventV2({
    required String playerId,
    required String eventType,
    String? deviceId,
  }) async {
    final res = await http.post(
      _uri('/discovery/v2/events'),
      headers: _authHeaders,
      body: jsonEncode({
        'playerId': playerId,
        'eventType': eventType,
        if (deviceId != null) 'deviceId': deviceId,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('Discovery V2 event failed (${res.statusCode}): ${res.body}');
    }
  }
}

// Platform Intelligence V2 contracts. These endpoints are optional accelerators:
// ordinary RLS-backed reads/writes remain safe without them.
extension PlatformIntelligenceApi on BackendApiService {
  Future<List<Map<String, dynamic>>> rankCandidates(List<Map<String, dynamic>> items, {int limit = 50}) async {
    final res = await http.post(_uri('/platform-intelligence/rank'), headers: _authHeaders, body: jsonEncode({'items': items, 'options': {'limit': limit}}));
    if (res.statusCode != 200) throw Exception('Ranking request failed: ${res.body}');
    return (jsonDecode(res.body)['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> safetyCheck(String text) async {
    final res = await http.post(_uri('/platform-intelligence/safety/content'), headers: _authHeaders, body: jsonEncode({'text': text}));
    if (res.statusCode != 200) throw Exception('Safety check failed: ${res.body}');
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> abuseRisk(Map<String, dynamic> signals) async {
    final res = await http.post(_uri('/platform-intelligence/abuse/risk'), headers: _authHeaders, body: jsonEncode(signals));
    if (res.statusCode != 200) throw Exception('Abuse risk request failed: ${res.body}');
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }
}
