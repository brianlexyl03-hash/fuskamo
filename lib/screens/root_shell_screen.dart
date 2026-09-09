import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/nav_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/offline_banner.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'groups_screen.dart';
import 'scouts_screen.dart';
import 'upload_screen.dart';

/// The single scaffold that hosts all 6 tabs, mirroring the web app's fixed
/// header/nav + swappable screen area — but using real Flutter navigation
/// state (IndexedStack) instead of DOM show/hide.
class RootShellScreen extends StatelessWidget {
  const RootShellScreen({super.key});

  static const _screens = [
    FeedScreen(),
    DiscoverScreen(),
    UploadScreen(),
    GroupsScreen(),
    ScoutsScreen(),
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
              Expanded(child: IndexedStack(index: nav.index, children: _screens)),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: nav.index,
          onTap: (i) => nav.setIndex(i),
        ),
      ),
    );
  }
}
