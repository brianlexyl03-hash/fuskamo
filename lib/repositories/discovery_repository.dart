import '../config/app_config.dart';
import '../models/ranked_player_model.dart';
import '../services/backend_api_service.dart';

/// Sits between DiscoveryProvider and BackendApiService, same role
/// PlayerRepository plays for PlayerService: translates raw exceptions into
/// plain strings the UI can show directly.
class DiscoveryRepository {
  final BackendApiService _api = BackendApiService();

  /// Returns (feed, null) on success, or (null, message) on failure — the
  /// message distinguishes "not signed in", "not a verified scout yet",
  /// and "network/server error" so the screen can react appropriately
  /// instead of showing one generic error state for all three.
  Future<({List<RankedPlayer>? feed, String? error})> getFeed({int limit = 30}) async {
    try {
      final raw = AppConfig.playerDiscoveryV2
          ? await _api.getDiscoveryFeedV2(limit: limit)
          : await _api.getDiscoveryFeed(limit: limit);
      return (feed: raw.map(RankedPlayer.fromJson).toList(), error: null);
    } on StateError catch (e) {
      return (feed: null, error: e.message);
    } catch (e) {
      final message = e.toString();
      if (message.contains('404')) {
        return (
          feed: null,
          error: 'Become a verified scout to unlock your personalized discovery feed.',
        );
      }
      return (feed: null, error: 'Could not load your discovery feed. Check your connection and try again.');
    }
  }

  /// Fire-and-forget engagement logging — a failed log call should never
  /// interrupt whatever the scout was actually doing (viewing a video,
  /// saving a player, tapping Contact).
  void logEvent({required String playerId, required String eventType}) {
    final request = AppConfig.playerDiscoveryV2
        ? _api.logDiscoveryEventV2(playerId: playerId, eventType: eventType)
        : _api.logDiscoveryEvent(playerId: playerId, eventType: eventType);
    request.catchError((_) {});
  }
}
