import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_model.dart';

/// Real local persistence — two concrete jobs, both wired into the app
/// rather than sitting unused:
///  1. Remember the last feed filter + whether onboarding has been seen.
///  2. Cache the last successfully-loaded feed so PlayerProvider has
///     something to show when a load fails offline, instead of a blank
///     empty state right under the offline banner.
class LocalStorage {
  static const _kLastFilter = 'last_feed_filter';
  static const _kOnboardingSeen = 'onboarding_seen';
  static const _kCachedFeed = 'cached_feed_v1';
  static const _kCachedFeedAt = 'cached_feed_at';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<void> setString(String key, String value) async {
    final prefs = await _prefs();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await _prefs();
    return prefs.getString(key);
  }

  // ── Last feed filter (by enum index — see FeedFilter in position_constants.dart) ──
  static Future<void> saveLastFilterIndex(int index) async {
    final prefs = await _prefs();
    await prefs.setInt(_kLastFilter, index);
  }

  static Future<int?> loadLastFilterIndex() async {
    final prefs = await _prefs();
    return prefs.getInt(_kLastFilter);
  }

  // ── Onboarding flag ──
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await _prefs();
    return prefs.getBool(_kOnboardingSeen) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await _prefs();
    await prefs.setBool(_kOnboardingSeen, true);
  }

  // ── Cached feed (offline fallback) ──
  static Future<void> cacheFeed(List<Player> players) async {
    final prefs = await _prefs();
    final encoded = jsonEncode(players.map((p) => p.toInsertJson()..['id'] = p.id).toList());
    await prefs.setString(_kCachedFeed, encoded);
    await prefs.setString(_kCachedFeedAt, DateTime.now().toIso8601String());
  }

  /// Returns null if nothing was ever cached. Cached rows are marked
  /// 'approved' since only approved players are ever cached in the first
  /// place (see PlayerProvider.loadPlayers).
  static Future<List<Player>?> loadCachedFeed() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_kCachedFeed);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((r) => Player.fromJson({...r as Map<String, dynamic>, 'status': 'approved'}))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> cachedFeedAge() async {
    final raw = await getString(_kCachedFeedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
