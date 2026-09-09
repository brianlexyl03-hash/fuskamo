import '../models/player_model.dart';
import 'supabase_service.dart';

/// Backs the real "save player" bookmark (replaces the fake "Player saved"
/// toast that used to sit on PlayerCard's 🔖 button). Requires a signed-in
/// user — RLS (see database/migrations/010_saved_players.sql) rejects
/// writes for anyone else's user_id anyway, but callers should check
/// AuthProvider.status before calling to give a clear "sign in to save
/// players" prompt instead of a confusing failure.
class SavedPlayersService {
  Future<Set<String>> fetchSavedPlayerIds(String userId) async {
    if (!SupabaseService.isReady) return {};
    final rows = await SupabaseService.client
        .from('saved_players')
        .select('player_id')
        .eq('user_id', userId);
    return (rows as List).map((r) => r['player_id'] as String).toSet();
  }

  /// Joins saved_players → players so the Saved screen can show full
  /// player cards, not just ids.
  Future<List<Player>> fetchSavedPlayers(String userId) async {
    if (!SupabaseService.isReady) return [];
    final rows = await SupabaseService.client
        .from('saved_players')
        .select('players(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .where((r) => r['players'] != null)
        .map((r) => Player.fromJson(r['players'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(String userId, String playerId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.from('saved_players').upsert({
      'user_id': userId,
      'player_id': playerId,
    });
  }

  Future<void> unsave(String userId, String playerId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client
        .from('saved_players')
        .delete()
        .eq('user_id', userId)
        .eq('player_id', playerId);
  }
}
