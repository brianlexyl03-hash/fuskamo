import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/messaging_models.dart';
import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_circle.dart';
import '../widgets/verified_badge.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final PublicProfile other;
  const ConversationScreen({super.key, required this.conversationId, required this.other});
  @override State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _repo = MessagingRepository();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _replyTo;

  @override
  void initState() { super.initState(); _repo.markRead(widget.conversationId); }
  @override void dispose() { _controller.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(conversationId: widget.conversationId, body: text, replyToId: _replyTo);
      _controller.clear();
      _replyTo = null;
      await _repo.markRead(widget.conversationId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    appBar: AppBar(
      titleSpacing: 0,
      title: Row(children: [InitialsCircle(initials: widget.other.initials, size: 36), const SizedBox(width: 10), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Flexible(child: Text(widget.other.displayName, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, weight: FontWeight.w800))), const SizedBox(width: 5), VerifiedBadge.forProfile(widget.other, size: 16)]), Text(widget.other.role.toUpperCase(), style: AppTheme.body(9, color: AppColors.sub, weight: FontWeight.w700))]))]),
      actions: [PopupMenuButton<String>(onSelected: (v) async { if (v == 'block') { await _repo.block(widget.other.userId); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account blocked.'))); Navigator.pop(context); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'block', child: Text('Block account'))])],
    ),
    body: Column(children: [
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: _repo.messageStream(widget.conversationId), builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Message stream error\n${snap.error}', textAlign: TextAlign.center, style: AppTheme.body(12, color: AppColors.sub)));
        final raw = snap.data ?? const [];
        final messages = raw.map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e))).where((m) => m.deletedAt == null).toList();
        if (messages.isEmpty) return Center(child: Text('START THE CONVERSATION', style: AppTheme.display(18, color: AppColors.sub)));
        WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
        return ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 18, 14, 20), itemCount: messages.length, itemBuilder: (_, i) {
          final m = messages[i];
          final mine = m.senderId != widget.other.userId;
          return GestureDetector(onLongPress: () => _messageMenu(m), child: Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78), decoration: BoxDecoration(color: mine ? AppColors.green : AppColors.card, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (m.replyToId != null) Text('Replying to a message', style: AppTheme.body(9, color: mine ? AppColors.black : AppColors.sub)), Text(m.body, style: AppTheme.body(14, color: mine ? AppColors.black : AppColors.text)), const SizedBox(height: 3), Text(_time(m.createdAt), style: AppTheme.body(9, color: mine ? AppColors.black.withValues(alpha:.55) : AppColors.sub))]))));
        });
      })),
      if (_replyTo != null) Container(width: double.infinity, color: AppColors.surface, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), child: Row(children: [Expanded(child: Text('Replying to message', style: AppTheme.body(11, color: AppColors.sub))), IconButton(onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close, size: 18))])),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 8), child: Row(children: [Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'Message', filled: true))), const SizedBox(width: 6), IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send))]))),
    ]),
  );

  Future<void> _messageMenu(DirectMessage m) async {
    final mine = m.senderId != widget.other.userId;
    final choice = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () => Navigator.pop(context, 'reply')), ListTile(leading: const Icon(Icons.favorite_border), title: const Text('React ❤️'), onTap: () => Navigator.pop(context, 'react')), if (mine && m.deletedAt == null) ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () => Navigator.pop(context, 'edit')), if (mine && m.deletedAt == null) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete'))])));
    if (!mounted || choice == null) return;
    if (choice == 'reply') setState(() => _replyTo = m.id);
    if (choice == 'react') await _repo.reactToMessage(m.id, 'love');
    if (choice == 'delete') await _repo.deleteMessage(m.id);
    if (choice == 'edit') { final c = TextEditingController(text: m.body); final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('EDIT MESSAGE'), content: TextField(controller: c, maxLines: 5), actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(context,true), child: const Text('SAVE'))])); if (ok == true) await _repo.editMessage(m.id, c.text); c.dispose(); }
  }

  String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
