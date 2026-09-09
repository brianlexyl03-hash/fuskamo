import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import '../repositories/group_repository.dart';

class GroupProvider extends ChangeNotifier {
  final GroupRepository _repo = GroupRepository();
  List<FuskamoGroup> _joined = [];
  List<FuskamoGroup> _recommended = [];
  bool _loading = false;
  String? _error;

  List<FuskamoGroup> get joined => _joined;
  List<FuskamoGroup> get recommended => _recommended;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_repo.getMyGroups(), _repo.getRecommendedGroups()]);
      _joined = results[0];
      _recommended = results[1];
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<FuskamoGroup?> create({required String name, required String slug, required String description, required String category, required String privacy, String? avatarUrl, bool joinApproval = false, String rules = ''}) async {
    try {
      final group = await _repo.createGroup(name: name, slug: slug, description: description, category: category, privacy: privacy, avatarUrl: avatarUrl, joinApproval: joinApproval, rules: rules);
      _joined = [group, ..._joined];
      _recommended = _recommended.where((g) => g.id != group.id).toList();
      notifyListeners();
      return group;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<FuskamoGroup> getDetails(FuskamoGroup group) => _repo.getGroup(group.id);

  Future<String?> join(FuskamoGroup group) async {
    try {
      final result = await _repo.joinGroup(group.id);
      if (result == 'joined') {
        await load();
      }
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> leave(String groupId) async {
    await _repo.leaveGroup(groupId);
    _joined = _joined.where((g) => g.id != groupId).toList();
    notifyListeners();
  }
}

class GroupChatProvider extends ChangeNotifier {
  final GroupRepository _repo = GroupRepository();
  final String groupId;
  String channel;
  List<GroupMessage> _messages = [];
  List<GroupPoll> _polls = [];
  StreamSubscription<List<GroupMessage>>? _subscription;
  bool _loading = true;
  String? _error;

  GroupChatProvider({required this.groupId, this.channel = 'member'});

  List<GroupMessage> get messages => _messages;
  List<GroupPoll> get polls => _polls;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> start() async {
    _loading = true;
    notifyListeners();
    try {
      _messages = await _repo.fetchMessages(groupId, channel: channel);
      _polls = await _repo.fetchPolls(groupId);
      await _repo.markRead(groupId);
      _subscription?.cancel();
      _subscription = _repo.streamMessages(groupId, channel: channel).listen((rows) {
        _messages = rows;
        _loading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    await _repo.sendMessage(groupId, text, channel: channel);
  }

  Future<void> react(String messageId, String emoji) => _repo.toggleReaction(messageId, emoji);
  Future<void> pinMessage(String id) => _repo.pinMessage(id);
  Future<void> unpinMessage(String id) => _repo.unpinMessage(id);
  Future<void> pinPoll(String id) async { await _repo.pinPoll(id); await refreshPolls(); }
  Future<void> unpinPoll(String id) async { await _repo.unpinPoll(id); await refreshPolls(); }
  Future<void> delete(String messageId) => _repo.deleteMessage(messageId);
  Future<void> toggleMessagePin(GroupMessage message) async {
    if (message.isPinned) { await _repo.unpinMessage(message.id); } else { await _repo.pinMessage(message.id); }
    await start();
  }
  Future<void> togglePollPin(GroupPoll poll) async {
    if (poll.isPinned) { await _repo.unpinPoll(poll.id); } else { await _repo.pinPoll(poll.id); }
    await refreshPolls();
  }
  Future<void> refreshPolls() async { _polls = await _repo.fetchPolls(groupId); notifyListeners(); }
  Future<void> vote(String pollId, String optionId, {bool multipleChoice = false}) async { await _repo.votePoll(pollId, optionId, multipleChoice: multipleChoice); await refreshPolls(); }
  Future<void> createPoll(String question, List<String> options) async { await _repo.createPoll(groupId, question, options); await refreshPolls(); }

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }
}
