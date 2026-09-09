import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/social_models.dart';
import '../repositories/social_repository.dart';
import '../theme/app_theme.dart';

class CreatorAnalyticsScreen extends StatefulWidget {
  const CreatorAnalyticsScreen({super.key});
  @override State<CreatorAnalyticsScreen> createState() => _CreatorAnalyticsScreenState();
}

class _CreatorAnalyticsScreenState extends State<CreatorAnalyticsScreen> {
  late Future<List<CreatorMetric>> _future;
  @override void initState() { super.initState(); _future = SocialRepository().analytics(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.black,
    appBar: AppBar(title: const Text('CREATOR ANALYTICS')),
    body: FutureBuilder<List<CreatorMetric>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.green));
        final rows = snapshot.data ?? <CreatorMetric>[];
        final views = rows.fold<int>(0, (sum, m) => sum + m.impressions + m.reelViews + m.storyViews);
        final likes = rows.fold<int>(0, (sum, m) => sum + m.likes);
        final comments = rows.fold<int>(0, (sum, m) => sum + m.comments);
        final followers = rows.fold<int>(0, (sum, m) => sum + m.followersGained);
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('LAST 30 DAYS', style: AppTheme.display(22, color: AppColors.green)),
            const SizedBox(height: 14),
            _metric('CONTENT VIEWS', views),
            _metric('LIKES', likes),
            _metric('COMMENTS', comments),
            _metric('NEW FOLLOWERS', followers),
            const SizedBox(height: 20),
            Text('DAILY PERFORMANCE', style: AppTheme.display(18)),
            const SizedBox(height: 8),
            ...rows.reversed.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m.day.day}/${m.day.month}/${m.day.year}'),
              subtitle: Text('${m.impressions} post impressions · ${m.reelViews} reel views · ${m.storyViews} story views'),
            )),
          ],
        );
      },
    ),
  );

  Widget _metric(String label, int value) => Card(
    color: AppColors.card,
    child: ListTile(
      title: Text(label, style: AppTheme.body(11, color: AppColors.sub)),
      trailing: Text('$value', style: AppTheme.display(24, color: AppColors.green)),
    ),
  );
}
