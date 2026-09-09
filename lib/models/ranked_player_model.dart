import 'player_model.dart';

/// One entry from GET /api/discovery/feed — a Player plus the score
/// discoveryEngine.js's calculateScore() gave it for the requesting scout.
/// Reuses Player.fromJson as-is: the feed response's "player" object is a
/// superset of the players table's normal columns (it also carries
/// league/height/foot/profile_completeness/quality_score/fraud_score and
/// the 7-day engagement counts), and Player.fromJson already ignores keys
/// it doesn't recognize.
class RankedPlayer {
  final Player player;
  final double score;
  final String? modelVersion;
  final bool exploration;
  final Map<String, dynamic> objectives;

  RankedPlayer({required this.player, required this.score, this.modelVersion, this.exploration = false, this.objectives = const {}});

  factory RankedPlayer.fromJson(Map<String, dynamic> json) {
    return RankedPlayer(
      player: Player.fromJson(json['player'] as Map<String, dynamic>),
      score: (json['score'] as num).toDouble(),
      modelVersion: json['modelVersion'] as String?,
      exploration: json['exploration'] == true,
      objectives: (json['objectives'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
