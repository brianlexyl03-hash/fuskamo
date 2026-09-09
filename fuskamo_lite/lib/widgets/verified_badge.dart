import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/messaging_models.dart';

class VerifiedBadge extends StatelessWidget {
  final String badgeType;
  final bool verified;
  final double size;
  const VerifiedBadge({super.key, required this.badgeType, required this.verified, this.size = 17});

  @override
  Widget build(BuildContext context) {
    if (!verified || badgeType == 'none') return const SizedBox.shrink();
    final color = switch (badgeType) {
      'gold' => const Color(0xFFFFC107),
      'blue' => const Color(0xFF1D9BF0),
      'black' => Colors.black,
      _ => AppColors.green,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2)),
      child: Icon(Icons.check, color: Colors.white, size: size * .68),
    );
  }

  static Widget forProfile(PublicProfile profile, {double size = 17}) => VerifiedBadge(badgeType: profile.badgeType, verified: profile.verified, size: size);
}
