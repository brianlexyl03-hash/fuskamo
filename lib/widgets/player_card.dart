import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_colors.dart';
import '../constants/position_constants.dart';
import '../helpers/contact_launcher.dart';
import '../helpers/messaging_launcher.dart';
import '../helpers/toast_helper.dart';
import '../models/player_model.dart';
import '../providers/saved_players_provider.dart';
import '../screens/video_player_screen.dart';
import '../theme/app_theme.dart';
import 'initials_circle.dart';
import 'verified_badge.dart';

/// Direct port of the web app's .player-card: accent stripe by position
/// group, jersey watermark, tag row, action row. All content comes from the
/// [player] passed in — nothing here is hardcoded.
class PlayerCard extends StatelessWidget {
  final Player player;

  /// Optional — fired on contact/save/video-open/share so a caller
  /// (DiscoveryFeedScreen) can log it against discoveryEngine.js's 7-day
  /// engagement scoring. Every other call site (FeedScreen, SearchScreen,
  /// saved-players list) leaves this null and behaves exactly as before.
  final void Function(String eventType)? onEngagement;

  const PlayerCard({super.key, required this.player, this.onEngagement});

  Color get _accent {
    switch (player.position) {
      case PlayerPosition.striker:
      case PlayerPosition.winger:
        return AppColors.green;
      case PlayerPosition.centralMid:
      case PlayerPosition.attackingMid:
        return AppColors.amber;
      case PlayerPosition.defender:
      case PlayerPosition.goalkeeper:
        return AppColors.red;
    }
  }

  void _openVideo(BuildContext context) {
    if (player.videoUrl == null) {
      ToastHelper.show(context, 'No video clip attached to this submission');
      return;
    }
    onEngagement?.call('view');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoUrl: player.videoUrl!, playerName: player.name),
      ),
    );
  }

  Future<void> _toggleSave(BuildContext context) async {
    final saved = context.read<SavedPlayersProvider>();
    if (!saved.isSignedIn) {
      ToastHelper.show(context, 'Sign in to save players — see the Profile tab');
      return;
    }
    final wasSaved = saved.isSaved(player.id);
    final ok = await saved.toggle(player.id);
    if (!context.mounted) return;
    if (!ok) {
      ToastHelper.show(context, 'Could not update — check your connection');
    } else {
      ToastHelper.show(context, wasSaved ? 'Removed from saved' : 'Player saved');
      if (!wasSaved) onEngagement?.call('save'); // only the save, not the unsave
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (player.jerseyNumber != null)
            Positioned(
              top: -10,
              right: 4,
              child: Text(
                player.jerseyNumber!,
                style: AppTheme.display(110, color: Colors.white.withValues(alpha: 0.028)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: player.videoUrl != null ? () => _openVideo(context) : null,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_accent, _accent.withValues(alpha: 0)]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Flexible(child: Text(player.name, style: AppTheme.display(21))), const SizedBox(width: 6), const SizedBox.shrink()]),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (player.isFeatured)
                                    _tag('🔥 FEATURED', AppColors.amber.withValues(alpha: 0.18), AppColors.amber),
                                  _tag(player.position.label, AppColors.green.withValues(alpha: 0.12), AppColors.green),
                                  _tag('${player.age}', AppColors.amber.withValues(alpha: 0.12), AppColors.amber),
                                  _tag(player.country, AppColors.surface, AppColors.sub),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InitialsCircle(initials: player.initials),
                      ],
                    ),
                    if (player.videoUrl != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _openVideo(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_circle_outline, color: AppColors.green, size: 18),
                              const SizedBox(width: 6),
                              Text('Watch clip', style: AppTheme.body(12, color: AppColors.green, weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: player.submittedBy == null
                                ? () {
                                    onEngagement?.call('contact');
                                    ContactLauncher.show(context, subjectName: player.name, email: player.contactEmail, phone: player.contactPhone);
                                  }
                                : () => MessagingLauncher.open(context, player.submittedBy),
                            icon: Icon(player.submittedBy == null ? Icons.alternate_email : Icons.chat_bubble_outline, size: 17),
                            label: Text(player.submittedBy == null ? 'CONTACT' : 'MESSAGE'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(34)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Consumer<SavedPlayersProvider>(
                          builder: (context, saved, _) => _ghostButton(
                            saved.isSaved(player.id) ? '★' : '🔖',
                            () => _toggleSave(context),
                            highlighted: saved.isSaved(player.id),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ghostButton('↗', () {
                          onEngagement?.call('share');
                          Share.share('${player.name} — via FUSKAMO');
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: AppTheme.body(10, color: fg, weight: FontWeight.w600)),
      );

  Widget _ghostButton(String icon, VoidCallback onTap, {bool highlighted = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: highlighted ? AppColors.green.withValues(alpha: 0.12) : AppColors.surface,
            border: Border.all(color: highlighted ? AppColors.green : AppColors.border),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: TextStyle(color: highlighted ? AppColors.green : AppColors.sub)),
        ),
      );
}
