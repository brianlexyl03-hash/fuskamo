class PublicProfile {
  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String bio;
  final String role;
  final bool verified;
  final String badgeType;
  final String verificationStatus;
  final double trustScore;
  final double profileCompletion;
  final String? identityClaim;
  final String? affiliationNotice;
  final int followersCount;
  final int followingCount;
  final int profileLikesCount;
  final int achievementPoints;
  final double scoreboardScore;
  final double momentumScore;

  const PublicProfile({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.bio = '',
    this.role = 'player',
    this.verified = false,
    this.badgeType = 'none',
    this.verificationStatus = 'unverified',
    this.trustScore = 0,
    this.profileCompletion = 0,
    this.identityClaim,
    this.affiliationNotice,
    this.followersCount = 0,
    this.followingCount = 0,
    this.profileLikesCount = 0,
    this.achievementPoints = 0,
    this.scoreboardScore = 0,
    this.momentumScore = 0,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String? ?? 'FUSKAMO Member',
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String? ?? '',
        role: json['role'] as String? ?? 'player',
        verified: json['verified'] as bool? ?? false,
        badgeType: json['badge_type'] as String? ?? 'none',
        verificationStatus: json['verification_status'] as String? ?? 'unverified',
        trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
        profileCompletion: (json['profile_completion'] as num?)?.toDouble() ?? 0,
        identityClaim: json['identity_claim'] as String?,
        affiliationNotice: json['affiliation_notice'] as String?,
        followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
        followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
        profileLikesCount: (json['profile_likes_count'] as num?)?.toInt() ?? 0,
        achievementPoints: (json['achievement_points'] as num?)?.toInt() ?? 0,
        scoreboardScore: (json['scoreboard_score'] as num?)?.toDouble() ?? 0,
        momentumScore: (json['momentum_score'] as num?)?.toDouble() ?? 0,
      );

  String get initials => displayName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase();
}

class DirectConversationPreview {
  final String id;
  final PublicProfile other;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime lastReadAt;

  const DirectConversationPreview({
    required this.id,
    required this.other,
    this.lastMessage,
    this.lastMessageAt,
    required this.lastReadAt,
  });

  bool get unread => lastMessageAt != null && lastMessageAt!.isAfter(lastReadAt);
}

class DirectMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? replyToId;
  final DateTime? deletedAt;
  final DateTime? editedAt;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.replyToId,
    this.deletedAt,
    this.editedAt,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        replyToId: json['reply_to_id'] as String?,
        deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
        editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at'] as String) : null,
      );
}
