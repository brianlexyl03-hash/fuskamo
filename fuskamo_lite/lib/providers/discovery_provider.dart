import 'package:flutter/foundation.dart';
import '../models/ranked_player_model.dart';
import '../repositories/discovery_repository.dart';

enum DiscoveryLoadState { idle, loading, loaded, error }

class DiscoveryProvider extends ChangeNotifier {
  final DiscoveryRepository _repo = DiscoveryRepository();

  List<RankedPlayer> _feed = [];
  DiscoveryLoadState _state = DiscoveryLoadState.idle;
  String? _errorMessage;

  List<RankedPlayer> get feed => _feed;
  DiscoveryLoadState get state => _state;
  String? get errorMessage => _errorMessage;

  Future<void> loadFeed() async {
    _state = DiscoveryLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repo.getFeed();
    if (result.feed != null) {
      _feed = result.feed!;
      _state = DiscoveryLoadState.loaded;
      // Logged exactly once per successful load, here — not from the
      // screen's itemBuilder, which Flutter can call repeatedly per scroll
      // frame and would massively over-count "views".
      for (final ranked in _feed) {
        _repo.logEvent(playerId: ranked.player.id, eventType: 'view');
      }
    } else {
      _errorMessage = result.error;
      _state = DiscoveryLoadState.error;
    }
    notifyListeners();
  }

  /// Call when a scout actually engages with a ranked result (opens the
  /// video, saves, taps Contact, shares) — feeds discoveryEngine.js's
  /// 7-day engagement scoring for every future feed load, not this one.
  void logEngagement(String playerId, String eventType) {
    _repo.logEvent(playerId: playerId, eventType: eventType);
  }
}
