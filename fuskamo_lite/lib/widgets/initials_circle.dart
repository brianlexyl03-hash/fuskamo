import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class InitialsCircle extends StatelessWidget {
  final String initials;
  final double size;

  const InitialsCircle({super.key, required this.initials, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: AppTheme.display(size * 0.45, color: AppColors.green)),
    );
  }
}
