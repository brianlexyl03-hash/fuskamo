import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart';
import 'supabase_service.dart';

class GroupService {
  SupabaseClient get _db => SupabaseService.client;

  User get _user {
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to use groups.');
    return user;
  }

  String get _displayName {
    final meta = _user.userMetadata ?? const {};
    final value = (meta['display_name'] ?? meta['full_name'] ?? meta['name'])?.toString().trim();
    if (value != null && value.isNotEmpty) return value.substring(0, value.length > 60 ? 60 : value.length);
    final email = _user.email ?? 'Member';
    final local = email.split('@').first;
    return local.substring(0, local.length > 60 ? 60 : local.length);
  }

  Future<FuskamoGroup> createGroup({
    required String name,
    required String slug,
    required String description,
    required String category,
    required String privacy,
    String? avatarUrl,
    bool joinApproval = false,
    String rules = '',
    bool allowMemberInvites = true,
    bool allowMemberMentions = true,
  }) async {
    final row = await _db.rpc('create_group', params: {
      'p_name': name,
      'p_slug': slug,
      'p_description': description,
      'p_category': category,
      'p_privacy': privacy,
      'p_avatar_url': avatarUrl,
      'p_join_approval': joinApproval,
      'p_rules': rules.trim(),
      'p_allow_member_invites': allowMemberInvites,
      'p_allow_member_mentions': allowMemberMentions,
      'p_display_name': _displayName,
    });
    final map = row is List ? Map<String, dynamic>.from(row.first as Map) : Map<String, dynamic>.from(row as Map);
    return FuskamoGroup.fromJson(map);
  }

  Future<List<FuskamoGroup>> getMyGroups({int limit = 50}) async {
    final rows = await _db.rpc('get_my_group_home', params: {'p_limit': limit}) as List;
    return rows.map((r) => FuskamoGroup.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<FuskamoGroup>> getRecommendedGroups({int limit = 20}) async {
    final rows = await _db.rpc('get_recommended_groups', params: {'p_limit': limit}) as List;
    return rows.map((r) => FuskamoGroup.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<String> joinGroup(String groupId) async {
    return await _db.rpc('join_group', params: {'p_group_id': groupId, 'p_display_name': _displayName}) as String;
  }

  Future<void> leaveGroup(String groupId) async {
    await _db.from('group_members').delete().eq('group_id', groupId).eq('user_id', _user.id);
  }

  Future<List<GroupMessage>> fetchMessages(String groupId, {String channel = 'member', int limit = 50}) async {
    final rows = await _db.from('group_messages').select().eq('group_id', groupId).eq('channel', channel).isFilter('deleted_at', null).order('created_at', ascending: false).limit(limit);
    final result = (rows as List).map((r) => GroupMessage.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    return result.reversed.toList();
  }

  Stream<List<GroupMessage>> streamMessages(String groupId, {String channel = 'member'}) {
    return _db.from('group_messages').stream(primaryKey: ['id']).eq('group_id', groupId).eq('channel', channel).order('created_at', ascending: true).map((rows) => rows.map((r) => GroupMessage.fromJson(Map<String, dynamic>.from(r))).where((m) => m.deletedAt == null).toList());
  }

  Future<void> sendMessage(String groupId, String content, {String channel = 'member', String? replyToId}) async {
    await _db.from('group_messages').insert({
      'group_id': groupId,
      'sender_id': _user.id,
      'sender_name': _displayName,
      'channel': channel,
      'content': content.trim(),
      'reply_to_id': replyToId,
      'client_message_id': '${_user.id}-${DateTime.now().microsecondsSinceEpoch}',
    });
  }

  Future<void> deleteMessage(String messageId) async => _db.from('group_messages').delete().eq('id', messageId);

  Future<void> toggleReaction(String messageId, String emoji) async {
    final existing = await _db.from('group_message_reactions').select('id').eq('message_id', messageId).eq('user_id', _user.id).eq('emoji', emoji).maybeSingle();
    if (existing == null) {
      await _db.from('group_message_reactions').insert({'message_id': messageId, 'user_id': _user.id, 'emoji': emoji});
    } else {
      await _db.from('group_message_reactions').delete().eq('id', existing['id']);
    }
  }

  Future<List<GroupPoll>> fetchPolls(String groupId) async {
    final polls = await _db.from('group_polls').select('id,group_id,question,multiple_choice,anonymous,closes_at,created_at,group_poll_options(id,label,position)').eq('group_id', groupId).order('created_at', ascending: false).limit(20);
    final ids = (polls as List).map((p) => p['id'] as String).toList();
    if (ids.isEmpty) return [];
    final pins = await _db.from('group_pins').select('poll_id').eq('group_id', groupId).inFilter('poll_id', ids);
    final pinnedPolls = (pins as List).map((r) => r['poll_id'] as String).toSet();
    final votes = await _db.from('group_poll_votes').select('poll_id,option_id,user_id').inFilter('poll_id', ids);
    final byOption = <String, int>{};
    final mine = <String>{};
    for (final raw in votes as List) {
      final v = Map<String, dynamic>.from(raw as Map);
      byOption[v['option_id'] as String] = (byOption[v['option_id'] as String] ?? 0) + 1;
      if (v['user_id'] == _user.id) mine.add(v['option_id'] as String);
    }
    return polls.map((raw) {
      final p = Map<String, dynamic>.from(raw as Map);
      final options = ((p['group_poll_options'] as List?) ?? const []).map((o) {
        final m = Map<String, dynamic>.from(o as Map);
        return {...m, 'votes': byOption[m['id'] as String] ?? 0, 'voted': mine.contains(m['id'] as String)};
      }).toList();
      return GroupPoll.fromJson({...p, 'options': options, 'is_pinned': pinnedPolls.contains(p['id'])});
    }).toList();
  }

  Future<String> createPoll(String groupId, String question, List<String> options, {bool multipleChoice = false}) async {
    return await _db.rpc('create_group_poll', params: {'p_group_id': groupId, 'p_question': question, 'p_options': options, 'p_multiple_choice': multipleChoice, 'p_anonymous': false}) as String;
  }

  Future<void> votePoll(String pollId, String optionId, {bool multipleChoice = false}) async {
    if (!multipleChoice) {
      await _db.from('group_poll_votes').delete().eq('poll_id', pollId).eq('user_id', _user.id);
    }
    await _db.from('group_poll_votes').upsert({'poll_id': pollId, 'option_id': optionId, 'user_id': _user.id}, onConflict: 'poll_id,option_id,user_id');
  }

  Future<void> markRead(String groupId) async => _db.rpc('mark_group_read', params: {'p_group_id': groupId});

  Future<void> promoteMember(String groupId, String userId, String role) async => _db.from('group_members').update({'role': role}).eq('group_id', groupId).eq('user_id', userId);

  Future<void> removeMember(String groupId, String userId) async => _db.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
  Future<void> banMember(String groupId, String userId, {String reason = '', DateTime? expiresAt}) async => _db.from('group_bans').upsert({'group_id': groupId, 'user_id': userId, 'banned_by': _user.id, 'reason': reason, 'expires_at': expiresAt?.toUtc().toIso8601String()});
  Future<void> unbanMember(String groupId, String userId) async => _db.from('group_bans').delete().eq('group_id', groupId).eq('user_id', userId);
  Future<List<Map<String,dynamic>>> groupBans(String groupId) async { final rows=await _db.from('group_bans').select().eq('group_id',groupId).order('created_at',ascending:false); return rows.map<Map<String,dynamic>>((r)=>Map<String,dynamic>.from(r)).toList(); }
  Future<void> setGroupPermission(String groupId,String role,String permission,bool enabled) async => _db.from('group_role_permissions').upsert({'group_id':groupId,'role':role,'permission':permission,'enabled':enabled},onConflict:'group_id,role,permission');

  Future<FuskamoGroup> getGroup(String groupId) async {
    final row = await _db.from('groups').select('id,name,slug,description,category,avatar_url,privacy,rules,verified,member_count,host_count,last_activity_at').eq('id', groupId).single();
    return FuskamoGroup.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> pinMessage(String messageId) async => _db.rpc('pin_group_message', params: {'p_message_id': messageId});
  Future<void> unpinMessage(String messageId) async => _db.rpc('unpin_group_message', params: {'p_message_id': messageId});
  Future<void> pinPoll(String pollId) async => _db.rpc('pin_group_poll', params: {'p_poll_id': pollId});
  Future<void> unpinPoll(String pollId) async => _db.rpc('unpin_group_poll', params: {'p_poll_id': pollId});

  Future<String> createInvite(String groupId, {DateTime? expiresAt, int? maxUses}) async {
    return await _db.rpc('create_group_invite', params: {
      'p_group_id': groupId,
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      'p_max_uses': maxUses,
    }) as String;
  }

  Future<GroupInvitePreview?> previewInvite(String code) async {
    final rows = await _db.rpc('preview_group_invite', params: {'p_code': code.trim()}) as List;
    if (rows.isEmpty) return null;
    return GroupInvitePreview.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<String> acceptInvite(String code) async => await _db.rpc('accept_group_invite', params: {'p_code': code.trim(), 'p_display_name': _displayName}) as String;

  Future<List<Map<String, dynamic>>> members(String groupId) async {
    final rows = await _db.from('group_members').select().eq('group_id', groupId).order('joined_at', ascending: true);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
}
