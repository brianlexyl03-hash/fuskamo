import '../models/scout_model.dart';
import 'supabase_service.dart';

class ScoutService {
  Future<List<Scout>> fetchVerifiedScouts() async {
    if (!SupabaseService.isReady) return [];
    final rows = await SupabaseService.client
        .from('scouts')
        .select()
        .eq('verified', true);
    return (rows as List).map((r) => Scout.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Powers the Feed → search bar's scouts section. Case-insensitive
  /// partial match on name, verified scouts only.
  Future<List<Scout>> searchVerifiedScouts(String query) async {
    if (!SupabaseService.isReady || query.trim().isEmpty) return [];
    final rows = await SupabaseService.client
        .from('scouts')
        .select()
        .eq('verified', true)
        .ilike('name', '%${query.trim()}%')
        .limit(30);
    return (rows as List).map((r) => Scout.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Inserts an unverified (pending) scout row. Returns the new row's id
  /// on success, or null on failure/not-configured.
  Future<String?> applyAsScout({
    required String name,
    String? organization,
    String? contactEmail,
    String? contactPhone,
  }) async {
    if (!SupabaseService.isReady) return null;
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    final row = await SupabaseService.client.from('scouts').insert({
      'name': name,
      'organization': organization,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'verified': false,
      if (currentUserId != null) 'user_id': currentUserId,
    }).select().single();
    return row['id'] as String?;
  }

  /// Fetches the signed-in user's own scout row, if any — used by the
  /// preferences screen, which needs to distinguish "not a scout yet",
  /// "application pending", and "verified" rather than just failing.
  Future<Scout?> fetchMyScout() async {
    if (!SupabaseService.isReady) return null;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await SupabaseService.client
        .from('scouts')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Scout.fromJson(row);
  }

  /// Updates the discovery-engine preference columns on the caller's own
  /// scout row. RLS (015_discovery_engine.sql, "Verified scouts can update
  /// their own preferences") only allows this for a verified row owned by
  /// the caller — an unverified applicant can't reach this successfully,
  /// which the UI surfaces as a plain failed-update rather than a silent
  /// no-op.
  Future<bool> updateMyPreferences({
    required List<String> preferredPositions,
    required List<String> preferredCountries,
    int? ageMin,
    int? ageMax,
    String? preferredFoot,
    int? preferredHeightMin,
  }) async {
    if (!SupabaseService.isReady) return false;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await SupabaseService.client
        .from('scouts')
        .update({
          'preferred_positions': preferredPositions,
          'preferred_countries': preferredCountries,
          'age_min': ageMin,
          'age_max': ageMax,
          'preferred_foot': preferredFoot,
          'preferred_height_min': preferredHeightMin,
        })
        .eq('user_id', userId)
        .select();
    return (rows as List).isNotEmpty;
  }
}
