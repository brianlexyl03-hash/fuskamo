import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../video/video_launch_config.dart';

class VideoComingSoonBanner extends StatelessWidget {
  final VoidCallback? onSupport;
  const VideoComingSoonBanner({super.key, this.onSupport});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.green.withOpacity(.35)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.cloud_upload_outlined, color: AppColors.green, size: 28),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(VideoLaunchConfig.title, style: AppTheme.body(13, color: AppColors.green, weight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(VideoLaunchConfig.message, style: AppTheme.body(12, color: AppColors.sub)),
        const SizedBox(height: 10),
        Text('Built already: secure upload sessions • virus scanning • metadata probing • thumbnails • HLS-ready processing • moderation • CDN playback architecture.', style: AppTheme.body(10, color: AppColors.text)),
        if (onSupport != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: onSupport, icon: const Icon(Icons.favorite_border, size: 16), label: const Text('SUPPORT FUSKAMO')),
        ],
      ])),
    ]),
  );
}
