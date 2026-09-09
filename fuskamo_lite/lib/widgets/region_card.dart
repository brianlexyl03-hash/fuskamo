import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/region_model.dart';
import '../theme/app_theme.dart';

class RegionCard extends StatelessWidget {
  final Region region;
  final VoidCallback onTap;
  const RegionCard({super.key, required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(region.flagEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(region.name.toUpperCase(), textAlign: TextAlign.center, style: AppTheme.display(15)),
            const SizedBox(height: 2),
            Text('${region.countries.length} countries', style: AppTheme.body(11, color: AppColors.green, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
