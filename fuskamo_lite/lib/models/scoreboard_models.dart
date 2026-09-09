import 'messaging_models.dart';

class ScoreboardEntry {
  final int rank;
  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String role;
  final bool verified;
  final String badgeType;
  final double score;
  final double momentum;
  final int followers;
  final int likes;
  final int achievementPoints;

  const ScoreboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.role,
    required this.verified,
    required this.badgeType,
    required this.score,
    required this.momentum,
    required this.followers,
    required this.likes,
    required this.achievementPoints,
  });

  factory ScoreboardEntry.fromJson(Map<String, dynamic> j) => ScoreboardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String? ?? 'FUSKAMO Member',
        username: j['username'] as String? ?? 'member',
        avatarUrl: j['avatar_url'] as String?,
        role: j['role'] as String? ?? 'fan',
        verified: j['verified'] as bool? ?? false,
        badgeType: j['badge_type'] as String? ?? 'none',
        score: (j['scoreboard_score'] as num?)?.toDouble() ?? 0,
        momentum: (j['momentum_score'] as num?)?.toDouble() ?? 0,
        followers: (j['followers_count'] as num?)?.toInt() ?? 0,
        likes: (j['profile_likes_count'] as num?)?.toInt() ?? 0,
        achievementPoints: (j['achievement_points'] as num?)?.toInt() ?? 0,
      );

  PublicProfile toProfile() => PublicProfile(
        userId: userId,
        displayName: displayName,
        username: username,
        avatarUrl: avatarUrl,
        role: role,
        verified: verified,
        badgeType: badgeType,
      );
}
