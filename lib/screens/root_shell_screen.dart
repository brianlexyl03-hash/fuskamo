import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nav_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/offline_banner.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';
import 'discover_screen.dart';

/// Persistent five-surface shell: Home, Explore, Create, Messages and Profile.
/// Each tab remains mounted so its scroll position and local UI state survive
/// tab changes. The order follows the social Home, Reels, Direct, Search, Profile shell.
class RootShellScreen extends StatelessWidget {
  const RootShellScreen({super.key});

  static const _screens = <Widget>[
    FeedScreen(),
    ReelsScreen(),
    MessagesScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<NavProvider>(
      builder: (context, nav, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: IndexedStack(
                  index: nav.index,
                  children: _screens,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: nav.index,
          onTap: nav.setIndex,
        ),
      ),
    );
  }
}
