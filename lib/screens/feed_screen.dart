import 'package:flutter/material.dart';
import 'social_feed_screen.dart';

/// The Home destination is the social feed. Player discovery lives in Explore,
/// while short-form video has its own Reels destination.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => const SocialFeedScreen();
}
