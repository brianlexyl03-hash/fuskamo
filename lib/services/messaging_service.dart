import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/messaging_models.dart';
import 'supabase_service.dart';

class MessagingService {
  SupabaseClient get _db => SupabaseService.client;
  String get _me => _db.auth.currentUser!.id;

  Future<PublicProfile?> getProfile(String userId) async {
    final row = await _db.from('profiles').select().eq('user_id', userId).maybeSingle();
    return row == null ? null : PublicProfile.fromJson(row);
  }

  Future<PublicProfile> ensureMyProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? website,
    String? instagram,
    String? xHandle,
    String? tiktok,
    String? snapchat,
    String? bluesky,
    String role = 'player',
  }) async {
    final row = await _db.rpc('ensure_my_profile', params: {
      'p_display_name': displayName,
      'p_username': username,
      'p_bio': bio,
      'p_avatar_url': avatarUrl,
      'p_website': website,
      'p_instagram': instagram,
      'p_x_handle': xHandle,
      'p_tiktok': tiktok,
      'p_snapchat': snapchat,
      'p_bluesky': bluesky,
      'p_role': role,
    });
    return PublicProfile.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<String> getOrCreateConversation(String otherUserId) async {
    final result = await _db.rpc('request_or_open_conversation', params: {'p_other_user': otherUserId});
    return result as String;
  }

  Future<List<DirectConversationPreview>> getConversations() async {
    final rows = await _db
        .from('direct_conversation_participants')
        .select('conversation_id,last_read_at')
        .eq('user_id', _me)
        .order('last_read_at', ascending: false);

    final output = <DirectConversationPreview>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final conversationId = row['conversation_id'] as String;
      final others = await _db
          .from('direct_conversation_participants')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', _me)
          .limit(1);
      if (others.isEmpty) continue;
      final other = await getProfile(others.first['user_id'] as String);
      if (other == null) continue;
      final latest = await _db
          .from('direct_messages')
          .select('body,created_at')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1);
      output.add(DirectConversationPreview(
        id: conversationId,
        other: other,
        lastMessage: latest.isEmpty ? null : latest.first['body'] as String?,
        lastMessageAt: latest.isEmpty ? null : DateTime.tryParse(latest.first['created_at'] as String),
        lastReadAt: DateTime.tryParse(row['last_read_at'] as String) ?? DateTime.now(),
      ));
    }
    output.sort((a, b) => (b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return output;
  }

  Stream<List<Map<String, dynamic>>> messageStream(String conversationId) {
    return _db.from('direct_messages').stream(primaryKey: ['id']).eq('conversation_id', conversationId).order('created_at');
  }

  Future<void> sendMessage({required String conversationId, required String body, String? replyToId}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    await _db.from('direct_messages').insert({
      'conversation_id': conversationId,
      'sender_id': _me,
      'body': trimmed,
      'reply_to_id': replyToId,
    });
    await _db.rpc('update_direct_conversation_activity', params: {'p_conversation': conversationId});
  }

  Future<void> markRead(String conversationId) => _db.rpc('mark_direct_conversation_read', params: {'p_conversation': conversationId});

  Future<void> block(String userId) async {
    await _db.from('user_blocks').upsert({'blocker_id': _me, 'blocked_id': userId});
  }

  Future<void> unblock(String userId) async {
    await _db.from('user_blocks').delete().eq('blocker_id', _me).eq('blocked_id', userId);
  }

  Future<List<Map<String,dynamic>>> messageRequests() async {
    final rows = await _db.from('message_requests').select().eq('recipient_id', _me).eq('status','pending').order('created_at', ascending: false);
    return rows.map<Map<String,dynamic>>((r)=>Map<String,dynamic>.from(r)).toList();
  }

  Future<String> sendMessageRequest(String recipientId) async => await _db.rpc('send_message_request', params: {'p_recipient': recipientId}) as String;

  Future<String?> respondMessageRequest(String id, bool accept) async {
    final r = await _db.rpc('respond_message_request', params: {'p_request': id, 'p_accept': accept});
    return r as String?;
  }

  Future<bool> reactToMessage(String messageId, String reaction) async => (_db.rpc('toggle_direct_message_reaction', params: {'p_message': messageId, 'p_reaction': reaction}) as Future).then((v)=>v as bool);

  Future<void> markDelivered(String messageId) => _db.rpc('mark_direct_message_delivered', params: {'p_message': messageId});
  Future<void> markMessageRead(String messageId) => _db.rpc('mark_direct_message_read', params: {'p_message': messageId});

  Future<void> editMessage(String id, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _db.from('direct_messages').update({'body': text, 'edited_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('sender_id', _me);
  }

  Future<void> deleteMessage(String id) async {
    await _db.from('direct_messages').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('sender_id', _me);
  }

  Future<bool> isTyping(String conversationId) async {
    final row = await _db.from('typing_presence').select('user_id').eq('conversation_id', conversationId).neq('user_id', _me).gt('expires_at', DateTime.now().toUtc().toIso8601String()).limit(1);
    return row.isNotEmpty;
  }

  Future<void> setTyping(String conversationId, bool typing) async {
    if (!typing) { await _db.from('typing_presence').delete().eq('conversation_id', conversationId).eq('user_id', _me); return; }
    await _db.from('typing_presence').upsert({'conversation_id': conversationId, 'user_id': _me, 'expires_at': DateTime.now().toUtc().add(const Duration(seconds: 4)).toIso8601String()});
  }
}
