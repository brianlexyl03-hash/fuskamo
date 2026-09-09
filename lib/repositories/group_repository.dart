import '../models/group_model.dart';
import '../services/group_service.dart';

class GroupRepository {
  final GroupService _service = GroupService();

  Future<FuskamoGroup> createGroup({required String name, required String slug, required String description, required String category, required String privacy, String? avatarUrl, bool joinApproval = false, String rules = ''}) => _service.createGroup(name: name, slug: slug, description: description, category: category, privacy: privacy, avatarUrl: avatarUrl, joinApproval: joinApproval, rules: rules);
  Future<List<FuskamoGroup>> getMyGroups() => _service.getMyGroups();
  Future<List<FuskamoGroup>> getRecommendedGroups() => _service.getRecommendedGroups();
  Future<String> joinGroup(String id) => _service.joinGroup(id);
  Future<void> leaveGroup(String id) => _service.leaveGroup(id);
  Future<List<GroupMessage>> fetchMessages(String id, {String channel = 'member'}) => _service.fetchMessages(id, channel: channel);
  Stream<List<GroupMessage>> streamMessages(String id, {String channel = 'member'}) => _service.streamMessages(id, channel: channel);
  Future<void> sendMessage(String id, String content, {String channel = 'member', String? replyToId}) => _service.sendMessage(id, content, channel: channel, replyToId: replyToId);
  Future<void> deleteMessage(String id) => _service.deleteMessage(id);
  Future<void> toggleReaction(String id, String emoji) => _service.toggleReaction(id, emoji);
  Future<List<GroupPoll>> fetchPolls(String id) => _service.fetchPolls(id);
  Future<String> createPoll(String id, String question, List<String> options) => _service.createPoll(id, question, options);
  Future<void> votePoll(String pollId, String optionId, {bool multipleChoice = false}) => _service.votePoll(pollId, optionId, multipleChoice: multipleChoice);
  Future<void> markRead(String id) => _service.markRead(id);
  Future<void> promoteMember(String groupId, String userId, String role) => _service.promoteMember(groupId, userId, role);
  Future<void> removeMember(String groupId, String userId) => _service.removeMember(groupId, userId);
  Future<void> banMember(String groupId,String userId,{String reason='',DateTime? expiresAt})=>_service.banMember(groupId,userId,reason:reason,expiresAt:expiresAt);
  Future<void> unbanMember(String groupId,String userId)=>_service.unbanMember(groupId,userId);
  Future<List<Map<String,dynamic>>> groupBans(String groupId)=>_service.groupBans(groupId);
  Future<void> setGroupPermission(String groupId,String role,String permission,bool enabled)=>_service.setGroupPermission(groupId,role,permission,enabled);
  Future<List<Map<String, dynamic>>> members(String groupId) => _service.members(groupId);
  Future<FuskamoGroup> getGroup(String groupId) => _service.getGroup(groupId);
  Future<void> pinMessage(String messageId) => _service.pinMessage(messageId);
  Future<void> unpinMessage(String messageId) => _service.unpinMessage(messageId);
  Future<void> pinPoll(String pollId) => _service.pinPoll(pollId);
  Future<void> unpinPoll(String pollId) => _service.unpinPoll(pollId);
  Future<String> createInvite(String groupId, {DateTime? expiresAt, int? maxUses}) => _service.createInvite(groupId, expiresAt: expiresAt, maxUses: maxUses);
  Future<GroupInvitePreview?> previewInvite(String code) => _service.previewInvite(code);
  Future<String> acceptInvite(String code) => _service.acceptInvite(code);
}
