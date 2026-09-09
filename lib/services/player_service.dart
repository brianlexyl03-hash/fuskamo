import 'dart:io';
import '../config/supabase_config.dart';
import '../constants/position_constants.dart';
import '../models/player_model.dart';
import 'supabase_service.dart';

class PlayerService {
  Future<List<Player>> fetchApprovedPlayers() async {
    if (!SupabaseService.isReady) return [];
    final rows = await SupabaseService.client
        .from('players')
        .select()
        .eq('status', 'approved')
        .order('featured_until', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Player.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Powers the Discover → region tap flow. Players don't have their own
  /// `region` column, so this filters on `country` being in the list the
  /// tapped Region defines (see models/region_model.dart).
  Future<List<Player>> fetchApprovedPlayersByCountries(List<String> countries) async {
    if (!SupabaseService.isReady || countries.isEmpty) return [];
    final rows = await SupabaseService.client
        .from('players')
        .select()
        .eq('status', 'approved')
        .inFilter('country', countries)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Player.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Powers the Feed → search bar. Case-insensitive partial match on name,
  /// approved players only (same visibility rule as the main feed).
  /// [query] can be empty if at least one filter is set — e.g. "show me
  /// all strikers under 18" with no name typed. Returns [] only when
  /// neither a query nor any filter was given, same as before.
  Future<List<Player>> searchApprovedPlayers(
    String query, {
    PlayerPosition? position,
    int? minAge,
    int? maxAge,
    String? country,
  }) async {
    final trimmed = query.trim();
    final hasFilters = position != null || minAge != null || maxAge != null || (country?.isNotEmpty ?? false);
    if (!SupabaseService.isReady || (trimmed.isEmpty && !hasFilters)) return [];

    var builder = SupabaseService.client.from('players').select().eq('status', 'approved');
    if (trimmed.isNotEmpty) builder = builder.ilike('name', '%$trimmed%');
    if (position != null) builder = builder.eq('position', position.dbValue);
    if (minAge != null) builder = builder.gte('age', minAge);
    if (maxAge != null) builder = builder.lte('age', maxAge);
    if (country != null && country.isNotEmpty) builder = builder.eq('country', country);

    final rows = await builder.order('created_at', ascending: false).limit(30);
    return (rows as List).map((r) => Player.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Powers Profile → "My Submissions" — relies on the "Owners can view
  /// their own submissions" RLS policy (011_ownership_and_scout_applications.sql)
  /// to see pending/rejected rows too, not just approved ones.
  Future<List<Player>> fetchMySubmissions(String userId) async {
    if (!SupabaseService.isReady) return [];
    final rows = await SupabaseService.client
        .from('players')
        .select()
        .eq('submitted_by', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Player.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Submits a new player as 'pending'. Returns the new row's id on
  /// success (needed so the post-submit "boost" flow can tag an M-Pesa
  /// payment to this exact player), or null on failure/not-configured.
  /// If [videoFile] is provided, it's uploaded to Supabase Storage first
  /// and the resulting public URL attached to the row.
  Future<String?> submitPlayer(Player player, {File? videoFile}) async {
    if (!SupabaseService.isReady) return null;

    String? videoUrl;
    if (videoFile != null) {
      final path = 'submissions/${DateTime.now().millisecondsSinceEpoch}-${videoFile.uri.pathSegments.last}';
      await SupabaseService.client.storage
          .from(SupabaseConfig.playerVideosBucket)
          .upload(path, videoFile);
      videoUrl = SupabaseService.client.storage
          .from(SupabaseConfig.playerVideosBucket)
          .getPublicUrl(path);
    }

    final payload = player.toInsertJson();
    if (videoUrl != null) payload['video_url'] = videoUrl;
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    if (currentUserId != null) payload['submitted_by'] = currentUserId;

    final row = await SupabaseService.client.from('players').insert(payload).select().single();
    return row['id'] as String?;
  }
}
