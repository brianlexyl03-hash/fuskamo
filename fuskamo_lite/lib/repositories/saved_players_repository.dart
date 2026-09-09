import '../models/player_model.dart';
import '../services/saved_players_service.dart';

class SavedPlayersRepository {
  final SavedPlayersService _service = SavedPlayersService();

  Future<Set<String>> getSavedPlayerIds(String userId) => _service.fetchSavedPlayerIds(userId);

  Future<List<Player>> getSavedPlayers(String userId) => _service.fetchSavedPlayers(userId);

  Future<void> save(String userId, String playerId) => _service.save(userId, playerId);

  Future<void> unsave(String userId, String playerId) => _service.unsave(userId, playerId);
}
