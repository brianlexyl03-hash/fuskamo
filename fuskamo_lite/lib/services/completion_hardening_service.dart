import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Final free-build platform surfaces that sit behind the existing screens.
/// Every method is RLS-bound to the signed-in user; staff-only operations
/// are additionally protected by Supabase permission policies.
class CompletionHardeningService {
  SupabaseClient get _db => SupabaseService.client;
  String get _me => _db.auth.currentUser!.id;

  // Stories / highlights / close friends.
  Future<String> createHighlight(String title, {String? coverUrl}) async {
    final row = await _db.from('story_highlights').insert({
      'owner_id': _me,
      'title': title.trim(),
      'cover_url': coverUrl,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<void> addStoryToHighlight(String highlightId, String storyId, {int position = 0}) async {
    await _db.from('story_highlight_items').upsert({
      'highlight_id': highlightId,
      'story_id': storyId,
      'position': position,
    }, onConflict: 'highlight_id,story_id');
  }

  Future<void> setCloseFriend(String userId, bool enabled) async {
    if (enabled) {
      await _db.from('close_friends').upsert({'owner_id': _me, 'friend_id': userId});
    } else {
      await _db.from('close_friends').delete().eq('owner_id', _me).eq('friend_id', userId);
    }
  }

  Future<List<Map<String, dynamic>>> closeFriends() async {
    final rows = await _db.from('close_friends').select('friend_id,created_at').eq('owner_id', _me).order('created_at', ascending: false);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Search history.
  Future<void> rememberSearch(String query, {String? objectType, String? objectId}) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await _db.from('search_history').insert({'user_id': _me, 'query': q, 'object_type': objectType, 'object_id': objectId});
  }

  Future<List<String>> recentSearches({int limit = 10}) async {
    final rows = await _db.from('search_history').select('query').eq('user_id', _me).order('created_at', ascending: false).limit(limit * 3);
    final seen = <String>{};
    final result = <String>[];
    for (final row in rows) {
      final q = (row['query'] as String).trim();
      if (seen.add(q.toLowerCase())) result.add(q);
      if (result.length == limit) break;
    }
    return result;
  }

  Future<void> clearSearchHistory() => _db.from('search_history').delete().eq('user_id', _me);

  // Moderation / appeals are server-authorized through RLS.
  Future<void> report({required String targetType, required String targetId, required String ruleCode, Map<String, dynamic> evidence = const {}}) async {
    await _db.from('moderation_flags').insert({'target_type': targetType, 'target_id': targetId, 'rule_code': ruleCode, 'evidence': evidence});
  }

  // Seasonal scoreboard snapshots.
  Future<List<Map<String, dynamic>>> currentSeason({String? role, int limit = 50}) async {
    final season = await _db.from('scoreboard_seasons').select('id,name,starts_at,ends_at,status').eq('status', 'active').order('starts_at', ascending: false).limit(1).maybeSingle();
    if (season == null) return const [];
    var query = _db.from('scoreboard_entries').select().eq('season_id', season['id']).order('rank').limit(limit);
    if (role != null && role.isNotEmpty) query = query.eq('role', role);
    final rows = await query;
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // Creator snapshots are read-only from the client.
  Future<List<Map<String, dynamic>>> creatorSnapshots({int days = 30}) async {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await _db.from('creator_daily_snapshots').select().eq('creator_id', _me).gte('day', from.toIso8601String().substring(0, 10)).order('day');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}
