import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/discovery_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/player_card.dart';

/// "Which player should this scout discover next?" — pushed from
/// ProfileScreen. Ranked by discoveryEngine.js (profile match, quality,
/// 7-day engagement, freshness, boosts, fraud penalty, diversity), not a
/// plain newest-first list like FeedScreen.
class DiscoveryFeedScreen extends StatelessWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DiscoveryProvider()..loadFeed(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('For you', style: AppTheme.display(18)),
        ),
        body: SafeArea(
          child: Consumer<DiscoveryProvider>(
            builder: (context, provider, _) {
              switch (provider.state) {
                case DiscoveryLoadState.idle:
                case DiscoveryLoadState.loading:
                  return const Center(child: CircularProgressIndicator(color: AppColors.green));

                case DiscoveryLoadState.error:
                  return RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: provider.loadFeed,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EmptyState(
                          icon: '🔎',
                          title: 'No feed yet',
                          description: provider.errorMessage ??
                              'Could not load your discovery feed. Pull to try again.',
                        ),
                      ],
                    ),
                  );

                case DiscoveryLoadState.loaded:
                  if (provider.feed.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.green,
                      onRefresh: provider.loadFeed,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          EmptyState(
                            icon: '🕸',
                            title: 'Nothing to rank yet',
                            description: 'No approved players match your preferences right now.',
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.green,
                    onRefresh: provider.loadFeed,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.feed.length,
                      itemBuilder: (context, i) {
                        final ranked = provider.feed[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PlayerCard(
                            player: ranked.player,
                            onEngagement: (eventType) =>
                                provider.logEngagement(ranked.player.id, eventType),
                          ),
                        );
                      },
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}
