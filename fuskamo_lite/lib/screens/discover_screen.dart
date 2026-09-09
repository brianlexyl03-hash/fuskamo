import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../localisation/app_localisations.dart';
import '../models/region_model.dart';
import '../theme/app_theme.dart';
import '../widgets/region_card.dart';
import 'region_detail_screen.dart';
import 'scoreboard_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('discover_title'), style: AppTheme.display(30)),
            const SizedBox(height: 4),
            Text(context.t('discover_subtitle'), style: AppTheme.body(12, color: AppColors.sub)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScoreboardScreen())), icon: const Icon(Icons.leaderboard_outlined), label: const Text('FUSKAMO SCOREBOARD'))),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                ),
                itemCount: Region.all.length,
                itemBuilder: (context, i) {
                  final region = Region.all[i];
                  return RegionCard(
                    region: region,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RegionDetailScreen(region: region)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
