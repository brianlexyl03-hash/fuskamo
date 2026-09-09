import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/position_constants.dart';
import '../models/player_model.dart';
import '../repositories/player_repository.dart';
import '../storage/local_storage.dart';

enum LoadState { idle, loading, loaded, error }

class PlayerProvider extends ChangeNotifier {
  final PlayerRepository _repo = PlayerRepository();

  List<Player> _players = [];
  LoadState _state = LoadState.idle;
  FeedFilter _activeFilter = FeedFilter.all;
  bool _fromCache = false;

  List<Player> get players => _filtered();
  LoadState get state => _state;
  FeedFilter get activeFilter => _activeFilter;

  /// True when the currently-shown list came from LocalStorage's cache
  /// rather than a live Supabase read — lets the feed screen show a small
  /// "showing cached results" note distinct from the offline banner.
  bool get isShowingCachedData => _fromCache;

  PlayerProvider() {
    _restoreLastFilter();
  }

  Future<void> _restoreLastFilter() async {
    final index = await LocalStorage.loadLastFilterIndex();
    if (index != null && index >= 0 && index < FeedFilter.values.length) {
      _activeFilter = FeedFilter.values[index];
      notifyListeners();
    }
  }

  Future<void> loadPlayers() async {
    _state = LoadState.loading;
    notifyListeners();
    try {
      _players = await _repo.getApprovedPlayers();
      _fromCache = false;
      _state = LoadState.loaded;
      // Fire-and-forget: refresh the offline fallback cache on every
      // successful load so it stays reasonably current.
      unawaited(LocalStorage.cacheFeed(_players));
    } catch (e) {
      final cached = await LocalStorage.loadCachedFeed();
      if (cached != null && cached.isNotEmpty) {
        _players = cached;
        _fromCache = true;
        _state = LoadState.loaded;
      } else {
        _state = LoadState.error;
      }
    }
    notifyListeners();
  }

  void setFilter(FeedFilter filter) {
    _activeFilter = filter;
    notifyListeners();
    unawaited(LocalStorage.saveLastFilterIndex(filter.index));
  }

  List<Player> _filtered() {
    // Featured/boosted players (see submitPlayer + M-Pesa boost flow)
    // surface first, then the usual newest-first order Supabase already
    // returned.
    final sorted = [..._players]..sort((a, b) {
        final aFeatured = a.isFeatured ? 1 : 0;
        final bFeatured = b.isFeatured ? 1 : 0;
        return bFeatured.compareTo(aFeatured);
      });

    switch (_activeFilter) {
      case FeedFilter.all:
        return sorted;
      case FeedFilter.striker:
        return sorted.where((p) =>
            p.position == PlayerPosition.striker || p.position == PlayerPosition.winger).toList();
      case FeedFilter.midfield:
        return sorted.where((p) =>
            p.position == PlayerPosition.centralMid || p.position == PlayerPosition.attackingMid).toList();
      case FeedFilter.defender:
        return sorted.where((p) => p.position == PlayerPosition.defender).toList();
      case FeedFilter.gk:
        return sorted.where((p) => p.position == PlayerPosition.goalkeeper).toList();
      case FeedFilter.u17:
        return sorted.where((p) => p.age <= 17).toList();
      case FeedFilter.u21:
        return sorted.where((p) => p.age <= 21).toList();
    }
  }

  /// Returns the new player's id on success (needed by the post-submit
  /// "boost" flow to tag the M-Pesa payment to this exact row), or null on
  /// failure.
  Future<String?> submitPlayer(Player player, {File? videoFile}) {
    return _repo.submitPlayer(player, videoFile: videoFile);
  }
}
