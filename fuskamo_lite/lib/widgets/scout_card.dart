import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../helpers/messaging_launcher.dart';
import 'verified_badge.dart';
import '../models/scout_model.dart';
import '../theme/app_theme.dart';
import 'initials_circle.dart';

class ScoutCard extends StatelessWidget {
  final Scout scout;
  const ScoutCard({super.key, required this.scout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          InitialsCircle(initials: scout.initials, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(scout.name, style: AppTheme.body(14, weight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    VerifiedBadge(badgeType: 'blue', verified: scout.verified, size: 15),
                  ],
                ),
                if (scout.organization != null)
                  Text(scout.organization!, style: AppTheme.body(12, color: AppColors.sub)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(scout.badgeType, style: AppTheme.body(10, color: AppColors.green)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => MessagingLauncher.open(context, scout.userId),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: const Text('💬', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
