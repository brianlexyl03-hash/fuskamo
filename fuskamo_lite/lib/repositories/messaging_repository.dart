import '../models/messaging_models.dart';
import '../services/messaging_service.dart';

class MessagingRepository {
  final MessagingService _service = MessagingService();
  Future<PublicProfile?> getProfile(String userId) => _service.getProfile(userId);
  Future<PublicProfile> ensureMyProfile({String? displayName,String? username,String? bio,String? avatarUrl,String? website,String? instagram,String? xHandle,String? tiktok,String? snapchat,String? bluesky,String role='player'}) => _service.ensureMyProfile(displayName:displayName,username:username,bio:bio,avatarUrl:avatarUrl,website:website,instagram:instagram,xHandle:xHandle,tiktok:tiktok,snapchat:snapchat,bluesky:bluesky,role:role);
  Future<String> getOrCreateConversation(String otherUserId) => _service.getOrCreateConversation(otherUserId);
  Future<List<DirectConversationPreview>> getConversations() => _service.getConversations();
  Stream<List<Map<String, dynamic>>> messageStream(String conversationId) => _service.messageStream(conversationId);
  Future<void> sendMessage({required String conversationId, required String body, String? replyToId}) => _service.sendMessage(conversationId:conversationId,body:body,replyToId:replyToId);
  Future<void> markRead(String conversationId) => _service.markRead(conversationId);
  Future<void> block(String userId) => _service.block(userId);
  Future<void> unblock(String userId) => _service.unblock(userId);

  Future<List<Map<String,dynamic>>> messageRequests() => _service.messageRequests();
  Future<String> sendMessageRequest(String id) => _service.sendMessageRequest(id);
  Future<String?> respondMessageRequest(String id, bool accept) => _service.respondMessageRequest(id, accept);
  Future<bool> reactToMessage(String id, String reaction) => _service.reactToMessage(id, reaction);
  Future<void> markDelivered(String id) => _service.markDelivered(id);
  Future<void> markMessageRead(String id) => _service.markMessageRead(id);
  Future<void> editMessage(String id, String body) => _service.editMessage(id, body);
  Future<void> deleteMessage(String id) => _service.deleteMessage(id);
  Future<void> setTyping(String conversationId, bool typing) => _service.setTyping(conversationId, typing);
}
