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
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _repo = MessagingRepository();
  final _searchController = TextEditingController();
  late Future<List<DirectConversationPreview>> _future;
  bool _unreadOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() => _query = _searchController.text.trim().toLowerCase());

  Future<List<DirectConversationPreview>> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) return [];
    return _repo.getConversations();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  List<DirectConversationPreview> _filter(List<DirectConversationPreview> items) {
    return items.where((c) {
      if (_unreadOnly && !c.unread) return false;
      if (_query.isEmpty) return true;
      return c.other.displayName.toLowerCase().contains(_query) ||
          c.other.role.toLowerCase().contains(_query) ||
          (c.lastMessage ?? '').toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text('MESSAGES', style: AppTheme.display(22)),
          actions: [
            IconButton(
              tooltip: 'Message requests',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageRequestsScreen()));
                if (mounted) _refresh();
              },
              icon: const Icon(Icons.mark_email_unread_outlined),
            ),
          ],
        ),
        body: FutureBuilder<List<DirectConversationPreview>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppColors.green));
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.sub),
                      const SizedBox(height: 12),
                      Text('Could not load messages', style: AppTheme.display(18)),
                      const SizedBox(height: 6),
                      Text('Check your connection and try again.', textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                    ],
                  ),
                ),
              );
            }

            final allItems = snap.data ?? [];
            final items = _filter(allItems);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search conversations',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.close),
                                    ),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _filterChip('All', !_unreadOnly, () => setState(() => _unreadOnly = false)),
                              const SizedBox(width: 8),
                              _filterChip('Unread', _unreadOnly, () => setState(() => _unreadOnly = true)),
                              const Spacer(),
                              Text('${allItems.length} chats', style: AppTheme.body(11, color: AppColors.sub)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (allItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'NO MESSAGES YET',
                        message: 'Open a player, scout, coach or club profile and tap Message.',
                      ),
                    )
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(
                        icon: Icons.search_off,
                        title: _unreadOnly ? 'ALL CAUGHT UP' : 'NO MATCHES',
                        message: _unreadOnly
                            ? 'You have no unread conversations.'
                            : 'Try another name, role or message.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = items[index];
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      InitialsCircle(initials: c.other.initials, size: 48),
                                      Positioned(right: -3, bottom: -2, child: VerifiedBadge.forProfile(c.other, size: 17)),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(child: Text(c.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(15, weight: c.unread ? FontWeight.w800 : FontWeight.w600))),
                                      const SizedBox(width: 6),
                                      _roleChip(c.other.role),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      c.lastMessage ?? 'Start the conversation',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.body(12, color: c.unread ? AppColors.text : AppColors.sub, weight: c.unread ? FontWeight.w700 : FontWeight.w400),
                                    ),
                                  ),
                                  trailing: c.unread
                                      ? Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle))
                                      : const Icon(Icons.chevron_right, color: AppColors.sub),
                                  onTap: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: c.id, other: c.other)));
                                    if (mounted) _refresh();
                                  },
                                ),
                                const Divider(color: AppColors.border, height: 1),
                              ],
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.green.withValues(alpha: 0.16),
        backgroundColor: AppColors.surface,
        labelStyle: AppTheme.body(12, color: selected ? AppColors.green : AppColors.sub, weight: selected ? FontWeight.w700 : FontWeight.w500),
        side: BorderSide(color: selected ? AppColors.green : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      );

  Widget _emptyState({required IconData icon, required String title, required String message}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: AppColors.sub),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: AppTheme.display(20)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)),
            ],
          ),
        ),
      );

  Widget _roleChip(String role) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5)),
        child: Text(role.toUpperCase(), style: AppTheme.body(8, color: AppColors.sub, weight: FontWeight.w700)),
      );
}
