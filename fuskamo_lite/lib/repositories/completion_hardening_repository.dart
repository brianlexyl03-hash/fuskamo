import '../services/completion_hardening_service.dart';

class CompletionHardeningRepository {
  final CompletionHardeningService _service = CompletionHardeningService();
  Future<String> createHighlight(String title, {String? coverUrl}) => _service.createHighlight(title, coverUrl: coverUrl);
  Future<void> addStoryToHighlight(String highlightId, String storyId, {int position = 0}) => _service.addStoryToHighlight(highlightId, storyId, position: position);
  Future<void> setCloseFriend(String userId, bool enabled) => _service.setCloseFriend(userId, enabled);
  Future<List<Map<String, dynamic>>> closeFriends() => _service.closeFriends();
  Future<void> rememberSearch(String query, {String? objectType, String? objectId}) => _service.rememberSearch(query, objectType: objectType, objectId: objectId);
  Future<List<String>> recentSearches({int limit = 10}) => _service.recentSearches(limit: limit);
  Future<void> clearSearchHistory() => _service.clearSearchHistory();
  Future<void> report({required String targetType, required String targetId, required String ruleCode, Map<String, dynamic> evidence = const {}}) => _service.report(targetType: targetType, targetId: targetId, ruleCode: ruleCode, evidence: evidence);
  Future<List<Map<String, dynamic>>> currentSeason({String? role, int limit = 50}) => _service.currentSeason(role: role, limit: limit);
  Future<List<Map<String, dynamic>>> creatorSnapshots({int days = 30}) => _service.creatorSnapshots(days: days);
}
