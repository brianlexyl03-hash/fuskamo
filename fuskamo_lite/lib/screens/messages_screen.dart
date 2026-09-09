import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../models/messaging_models.dart';
import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_circle.dart';
import '../widgets/verified_badge.dart';
import 'conversation_screen.dart';
import 'message_requests_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _repo = MessagingRepository();
  late Future<List<DirectConversationPreview>> _future;

  @override
  void initState() { super.initState(); _future = _load(); }
  Future<List<DirectConversationPreview>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) return [];
    return _repo.getConversations();
  }
  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    appBar: AppBar(title: Text('MESSAGES', style: AppTheme.display(22)), actions: [IconButton(tooltip: 'Message requests', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageRequestsScreen())), icon: const Icon(Icons.mark_email_unread_outlined))]),
    body: FutureBuilder<List<DirectConversationPreview>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.green));
        if (snap.hasError) return Center(child: Text('Could not load messages.\n${snap.error}', textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)));
        final items = snap.data ?? [];
        if (items.isEmpty) return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(children: [const SizedBox(height: 180), Center(child: Icon(Icons.chat_bubble_outline, size: 54, color: AppColors.sub)), const SizedBox(height: 16), Center(child: Text('NO MESSAGES YET', style: AppTheme.display(20))), const SizedBox(height: 8), Center(child: Text('Open a player, scout, coach or club profile and tap Message.', style: AppTheme.body(13, color: AppColors.sub), textAlign: TextAlign.center))]));
        return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView.separated(padding: const EdgeInsets.all(12), itemCount: items.length, separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1), itemBuilder: (_, i) {
          final c = items[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            leading: Stack(clipBehavior: Clip.none, children: [InitialsCircle(initials: c.other.initials, size: 48), Positioned(right: -3, bottom: -2, child: VerifiedBadge.forProfile(c.other, size: 17))]),
            title: Row(children: [Flexible(child: Text(c.other.displayName, style: AppTheme.body(15, weight: c.unread ? FontWeight.w800 : FontWeight.w600))), const SizedBox(width: 6), _roleChip(c.other.role)]),
            subtitle: Text(c.lastMessage ?? 'Start the conversation', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12, color: c.unread ? AppColors.text : AppColors.sub, weight: c.unread ? FontWeight.w700 : FontWeight.w400)),
            trailing: c.unread ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)) : const Icon(Icons.chevron_right),
            onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: c.id, other: c.other))); if (mounted) _refresh(); },
          );
        }));
      },
    ),
  );

  Widget _roleChip(String role) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5)), child: Text(role.toUpperCase(), style: AppTheme.body(8, color: AppColors.sub, weight: FontWeight.w700)));
}
