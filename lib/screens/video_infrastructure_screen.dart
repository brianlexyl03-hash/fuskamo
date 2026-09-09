import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../video/video_launch_config.dart';
import '../widgets/video_coming_soon_banner.dart';

class VideoInfrastructureScreen extends StatelessWidget {
  const VideoInfrastructureScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    appBar: AppBar(title: const Text('VIDEO INFRASTRUCTURE')),
    body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      const VideoComingSoonBanner(),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('READY FOR CLOUD', style: AppTheme.display(22, color: AppColors.green)),
        const SizedBox(height: 8),
        Text('FUSKAMO is not deleting the video product. The storage switch is intentionally off until the project has the resources to run it reliably.', style: AppTheme.body(13, color: AppColors.sub)),
        const SizedBox(height: 18),
        ...const [
          ('Secure upload sessions', Icons.lock_outline),
          ('File validation + virus scanning', Icons.verified_user_outlined),
          ('Metadata and duration checks', Icons.data_object),
          ('Thumbnail generation pipeline', Icons.image_outlined),
          ('Transcoding job queue', Icons.transform_outlined),
          ('HLS/adaptive streaming ready', Icons.stream_outlined),
          ('Content moderation hooks', Icons.shield_outlined),
          ('CDN playback abstraction', Icons.public_outlined),
          ('Per-user storage quotas', Icons.storage_outlined),
        ].map((x) => ListTile(leading: Icon(x.$2, color: AppColors.green), title: Text(x.$1), subtitle: const Text('Infrastructure prepared — waiting for cloud resources.'))),
        const SizedBox(height: 12),
        Text('Storage budget policy', style: AppTheme.display(18, color: AppColors.text)),
        const SizedBox(height: 6),
        Text('Initial limits are designed around 50 MB uploads and 3-minute short videos. When cloud storage is funded, the provider can be enabled without redesigning the social schema.', style: AppTheme.body(12, color: AppColors.sub)),
        const SizedBox(height: 20),
        Center(child: Text('Support FUSKAMO 💖 — help us get the resources to buy cloud storage.', textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.green, weight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(child: Text('Cloud video hosting is currently OFF. No payment unlocks a video feature or verification badge.', textAlign: TextAlign.center, style: AppTheme.body(10, color: AppColors.sub))),
      ])),
    ]),
  );
}
