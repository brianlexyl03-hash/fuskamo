import 'dart:io';
import '../constants/position_constants.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';

/// Sits between providers and services so screens never call Supabase
/// directly. Currently a thin pass-through — this is where caching,
/// retry logic, or an offline queue would go in Phase 2.
class PlayerRepository {
  final PlayerService _service = PlayerService();

  Future<List<Player>> getApprovedPlayers() => _service.fetchApprovedPlayers();

  Future<List<Player>> getApprovedPlayersByCountries(List<String> countries) =>
      _service.fetchApprovedPlayersByCountries(countries);

  Future<List<Player>> searchApprovedPlayers(
    String query, {
    PlayerPosition? position,
    int? minAge,
    int? maxAge,
    String? country,
  }) =>
      _service.searchApprovedPlayers(query, position: position, minAge: minAge, maxAge: maxAge, country: country);

  Future<List<Player>> getMySubmissions(String userId) => _service.fetchMySubmissions(userId);

  /// Returns the new player's id on success, or null on failure.
  Future<String?> submitPlayer(Player player, {File? videoFile}) =>
      _service.submitPlayer(player, videoFile: videoFile);
}
