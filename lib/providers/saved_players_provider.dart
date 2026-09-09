import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../repositories/saved_players_repository.dart';

/// Attached to the signed-in user id via ChangeNotifierProxyProvider in
/// app.dart, same pattern as NotificationProvider — clears and reloads
/// whenever who's signed in changes.
class SavedPlayersProvider extends ChangeNotifier {
  final SavedPlayersRepository _repo = SavedPlayersRepository();
  String? _userId;
  Set<String> _savedIds = {};

  bool get isSignedIn => _userId != null;
  bool isSaved(String playerId) => _savedIds.contains(playerId);

  void attachUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _savedIds = {};
    notifyListeners();
    if (userId != null) _loadIds(userId);
  }

  Future<void> _loadIds(String userId) async {
    final ids = await _repo.getSavedPlayerIds(userId);
    if (_userId != userId) return; // user changed again while this was in flight
    _savedIds = ids;
    notifyListeners();
  }

  /// Returns false (and changes nothing) if nobody's signed in — the
  /// caller (PlayerCard) shows a "sign in to save players" prompt in
  /// that case instead of silently doing nothing.
  Future<bool> toggle(String playerId) async {
    final userId = _userId;
    if (userId == null) return false;

    final wasSaved = _savedIds.contains(playerId);
    // Optimistic update.
    if (wasSaved) {
      _savedIds.remove(playerId);
    } else {
      _savedIds.add(playerId);
    }
    notifyListeners();

    try {
      if (wasSaved) {
        await _repo.unsave(userId, playerId);
      } else {
        await _repo.save(userId, playerId);
      }
      return true;
    } catch (e) {
      // Roll back on failure.
      if (wasSaved) {
        _savedIds.add(playerId);
      } else {
        _savedIds.remove(playerId);
      }
      notifyListeners();
      return false;
    }
  }

  Future<List<Player>> loadFullList() {
    final userId = _userId;
    if (userId == null) return Future.value([]);
    return _repo.getSavedPlayers(userId);
  }
}
