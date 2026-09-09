import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'video_infrastructure_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_preferences_screen.dart';
import 'messages_screen.dart';
import '../repositories/messaging_repository.dart';
import '../widgets/verified_badge.dart';
import '../widgets/affiliation_banner.dart';
import 'verification_center_screen.dart';
import '../repositories/badge_repository.dart';

class AccountSettingsScreen extends StatelessWidget {
  final AuthProvider auth;
  const AccountSettingsScreen({super.key, required this.auth});
  String _meta(String key) => auth.user?.userMetadata?[key]?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    final username = _meta('username');
    final name = _meta('display_name').isEmpty
        ? (username.isEmpty ? 'FUSKAMO Member' : username)
        : _meta('display_name');
    final bio = _meta('bio');
    final avatar = _meta('avatar_url');
    return Scaffold(
      appBar: AppBar(
        title: Text('ACCOUNT SETTINGS', style: AppTheme.display(22)),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          _sectionHeader('PUBLIC PROFILE', 'EDIT', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          }),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  backgroundColor: AppColors.surface,
                  child: avatar.isEmpty
                      ? Text(name.isEmpty ? 'F' : name[0].toUpperCase(), style: AppTheme.display(30, color: AppColors.green))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTheme.display(23)),
                      const SizedBox(height: 2),
                      Text('@${username.isEmpty ? 'username' : username}', style: AppTheme.body(13, color: AppColors.sub)),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(bio, style: AppTheme.body(13)),
                      ],
                      if (_meta('website').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.link, size: 18, color: AppColors.green),
                          const SizedBox(width: 5),
                          Flexible(child: Text(_meta('website'), style: AppTheme.body(12, color: AppColors.green))),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('PRIVATE INFO', 'EDIT', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email and phone are managed by your verified account.')));
          }),
          _privateField('EMAIL', user?.email ?? 'Not set'),
          _privateField('PHONE', user?.phone ?? 'Not set'),
          const SizedBox(height: 24),
          Text('TRUST & IDENTITY', style: AppTheme.display(22)),
          FutureBuilder(
            future: MessagingRepository().getProfile(user?.id ?? ''),
            builder: (context, snap) {
              final p = snap.data;
              if (p == null) return const SizedBox.shrink();
              return Column(children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: VerifiedBadge.forProfile(p, size: 20),
                  title: Text('${p.role.toUpperCase()} ACCOUNT', style: AppTheme.body(15, weight: FontWeight.w700)),
                  subtitle: Text(p.verified ? 'Verified ${p.badgeType} identity' : 'Not verified', style: AppTheme.body(11, color: AppColors.sub)),
                ),
                AffiliationBanner(notice: p.affiliationNotice),
              ]);
            },
          ),
          _tile(context, Icons.verified_outlined, 'Trust & Verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationCenterScreen()))),
          FutureBuilder(
            future: BadgeRepository().achievements(user?.id ?? ''),
            builder: (context, snap) {
              final achievements = snap.data ?? const [];
              if (achievements.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ACHIEVEMENTS', style: AppTheme.display(18)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: achievements.take(6).map((x) => Chip(avatar: Text(x.icon), label: Text(x.name))).toList()),
                ]),
              );
            },
          ),
          _tile(context, Icons.video_library_outlined, 'Video Infrastructure', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoInfrastructureScreen()))),
          _tile(context, Icons.chat_bubble_outline, 'Messages', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()))),
          _tile(context, Icons.notifications_none, 'Push Notifications', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()))),
          _tile(context, Icons.chat_bubble_outline, 'Message Requests', () => _simple(context, 'MESSAGE REQUESTS', 'Control who can start a direct conversation with you.')),
          _tile(context, Icons.brightness_6_outlined, 'Appearance', () => _simple(context, 'APPEARANCE', 'Choose your preferred app appearance.')),
          _tile(context, Icons.waving_hand_outlined, 'Share Feedback', () => _simple(context, 'SHARE FEEDBACK', 'Tell us what should be improved in FUSKAMO.')),
          const SizedBox(height: 18),
          Text('LEGAL', style: AppTheme.display(22)),
          _tile(context, Icons.description_outlined, 'Terms of Service', () => _simple(context, 'TERMS OF SERVICE', 'FUSKAMO terms will be displayed here.')),
          _tile(context, Icons.info_outline, 'Privacy Policy', () => _simple(context, 'PRIVACY POLICY', 'FUSKAMO privacy information will be displayed here.')),
          const SizedBox(height: 18),
          SizedBox(height: 52, child: OutlinedButton.icon(onPressed: auth.signOut, icon: const Icon(Icons.logout), label: const Text('LOG OUT'))),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [Expanded(child: Text(title, style: AppTheme.display(21))), TextButton(onPressed: onTap, child: Text(action, style: AppTheme.body(14, color: AppColors.green, weight: FontWeight.w800)))]),
  );
  Widget _privateField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppTheme.display(14)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)), child: Text(value, style: AppTheme.body(14, color: AppColors.sub)))]),
  );
  Widget _tile(BuildContext c, IconData icon, String title, VoidCallback onTap) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppColors.text), title: Text(title, style: AppTheme.body(15, weight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: onTap);
  Future<void> _simple(BuildContext c, String title, String body) => showDialog(context: c, builder: (_) => AlertDialog(title: Text(title, style: AppTheme.display(20)), content: Text(body, style: AppTheme.body(14)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('CLOSE'))]));
}
