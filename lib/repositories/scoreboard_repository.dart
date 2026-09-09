import '../models/scoreboard_models.dart';
import '../services/scoreboard_service.dart';

class ScoreboardRepository {
  final ScoreboardService _service = ScoreboardService();
  Future<List<ScoreboardEntry>> load({String category = 'global', int limit = 50}) => _service.load(category: category, limit: limit);
  Future<void> refreshMyScore() => _service.refreshMyScore();
}
