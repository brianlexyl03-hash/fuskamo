class FuskamoGroup {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String category;
  final String? avatarUrl;
  final String privacy;
  final String rules;
  final bool verified;
  final int memberCount;
  final int hostCount;
  final DateTime lastActivityAt;
  final bool joined;
  final String? role;
  final String? displayName;
  final int unreadCount;
  final String? latestMessage;
  final String? latestSender;
  final String? latestChannel;
  final double? score;

  const FuskamoGroup({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    this.avatarUrl,
    required this.privacy,
    this.rules = '',
    required this.verified,
    required this.memberCount,
    required this.hostCount,
    required this.lastActivityAt,
    this.joined = false,
    this.role,
    this.displayName,
    this.unreadCount = 0,
    this.latestMessage,
    this.latestSender,
    this.latestChannel,
    this.score,
  });

  factory FuskamoGroup.fromJson(Map<String, dynamic> json) => FuskamoGroup(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unnamed Group',
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General Football',
        avatarUrl: json['avatar_url'] as String?,
        privacy: json['privacy'] as String? ?? 'public',
        rules: json['rules'] as String? ?? '',
        verified: json['verified'] as bool? ?? false,
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        hostCount: (json['host_count'] as num?)?.toInt() ?? 0,
        lastActivityAt: DateTime.tryParse(json['last_activity_at'] as String? ?? '') ?? DateTime.now(),
        joined: json['joined'] as bool? ?? false,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        latestMessage: json['latest_message'] as String?,
        latestSender: json['latest_sender'] as String?,
        latestChannel: json['latest_channel'] as String?,
        score: (json['score'] as num?)?.toDouble(),
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  bool get isStaff => role == 'owner' || role == 'host' || role == 'moderator';
}

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String channel;
  final String content;
  final String messageType;
  final String? replyToId;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.channel,
    required this.content,
    required this.messageType,
    this.replyToId,
    this.isPinned = false,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String? ?? 'Member',
        channel: json['channel'] as String? ?? 'member',
        content: json['content'] as String? ?? '',
        messageType: json['message_type'] as String? ?? 'text',
        replyToId: json['reply_to_id'] as String?,
        isPinned: json['is_pinned'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        editedAt: json['edited_at'] != null ? DateTime.tryParse(json['edited_at'] as String) : null,
        deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
      );
}

class GroupPollOption {
  final String id;
  final String label;
  final int position;
  final int votes;
  final bool voted;

  const GroupPollOption({required this.id, required this.label, required this.position, this.votes = 0, this.voted = false});

  factory GroupPollOption.fromJson(Map<String, dynamic> json) => GroupPollOption(
        id: json['id'] as String,
        label: json['label'] as String,
        position: (json['position'] as num?)?.toInt() ?? 0,
        votes: (json['votes'] as num?)?.toInt() ?? 0,
        voted: json['voted'] as bool? ?? false,
      );
}

class GroupPoll {
  final String id;
  final String groupId;
  final String question;
  final bool multipleChoice;
  final bool anonymous;
  final DateTime? closesAt;
  final List<GroupPollOption> options;
  final bool isPinned;

  const GroupPoll({required this.id, required this.groupId, required this.question, required this.multipleChoice, required this.anonymous, this.closesAt, required this.options, this.isPinned = false});

  factory GroupPoll.fromJson(Map<String, dynamic> json) => GroupPoll(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        question: json['question'] as String,
        multipleChoice: json['multiple_choice'] as bool? ?? false,
        anonymous: json['anonymous'] as bool? ?? false,
        closesAt: json['closes_at'] != null ? DateTime.tryParse(json['closes_at'] as String) : null,
        isPinned: json['is_pinned'] as bool? ?? false,
        options: ((json['options'] as List?) ?? const []).map((e) => GroupPollOption.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class GroupInvitePreview {
  final String groupId;
  final String name;
  final String description;
  final String rules;
  final String privacy;
  final String? avatarUrl;
  final int memberCount;
  final int hostCount;
  final bool verified;

  const GroupInvitePreview({required this.groupId, required this.name, required this.description, required this.rules, required this.privacy, this.avatarUrl, this.memberCount = 0, this.hostCount = 0, this.verified = false});

  factory GroupInvitePreview.fromJson(Map<String, dynamic> json) => GroupInvitePreview(
    groupId: json['group_id'] as String,
    name: json['name'] as String? ?? 'Group',
    description: json['description'] as String? ?? '',
    rules: json['rules'] as String? ?? '',
    privacy: json['privacy'] as String? ?? 'secret',
    avatarUrl: json['avatar_url'] as String?,
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    hostCount: (json['host_count'] as num?)?.toInt() ?? 0,
    verified: json['verified'] as bool? ?? false,
  );
}
