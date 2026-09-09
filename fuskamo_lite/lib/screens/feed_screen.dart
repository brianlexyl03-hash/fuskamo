import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/position_constants.dart';
import '../localisation/app_localisations.dart';
import '../providers/notification_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_pill.dart';
import '../widgets/player_card.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'social_feed_screen.dart';
import 'reels_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _tab = 0;
  static const _filters = [
    (FeedFilter.all, 'All'), (FeedFilter.striker, 'Striker'), (FeedFilter.midfield, 'Midfield'),
    (FeedFilter.defender, 'Defender'), (FeedFilter.gk, 'GK'), (FeedFilter.u17, 'U-17'), (FeedFilter.u21, 'U-21'),
  ];

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PlayerProvider>().loadPlayers());
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _header(context),
      Container(
        height: 44,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [_tabButton('PLAYERS', 0), _tabButton('SOCIAL', 1), _tabButton('REELS', 2)]),
      ),
      if (_tab == 0)
        Consumer<PlayerProvider>(
          builder: (context, p, _) => SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _filters.map((f) => FilterPill(label: f.$2, active: p.activeFilter == f.$1, onTap: () => p.setFilter(f.$1))).toList(),
            ),
          ),
        ),
      Expanded(child: _tab == 0 ? _players() : _tab == 1 ? const SocialFeedScreen() : const ReelsScreen()),
    ],
  );

  Widget _tabButton(String text, int index) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tab = index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == index ? AppColors.green : Colors.transparent, width: 2))),
        child: Text(text, style: AppTheme.body(12, color: _tab == index ? AppColors.green : AppColors.sub, weight: FontWeight.bold)),
      ),
    ),
  );

  Widget _players() => Consumer<PlayerProvider>(
    builder: (context, p, _) {
      if (p.state == LoadState.loading) return const Center(child: CircularProgressIndicator(color: AppColors.green));
      if (p.players.isEmpty) return SingleChildScrollView(child: EmptyState(icon: '⚽', title: context.t('feed_empty_title'), description: context.t('feed_empty_description')));
      return RefreshIndicator(color: AppColors.green, onRefresh: p.loadPlayers, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: p.players.length, itemBuilder: (_, i) => PlayerCard(player: p.players[i])));
    },
  );

  Widget _header(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(color: AppColors.black, border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(text: TextSpan(children: [TextSpan(text: 'F', style: AppTheme.display(26, color: AppColors.green)), TextSpan(text: 'USKAMO', style: AppTheme.display(26, color: AppColors.text))])),
        Row(children: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.sub), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
          Consumer<NotificationProvider>(
            builder: (context, n, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(icon: const Icon(Icons.notifications_none, color: AppColors.sub), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                if (n.unreadCount > 0)
                  Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)), child: Text(n.unreadCount > 9 ? '9+' : '${n.unreadCount}', style: AppTheme.body(9, color: AppColors.black, weight: FontWeight.bold)))),
              ],
            ),
          ),
        ]),
      ],
    ),
  );
}
