import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const EmptyState({super.key, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.display(20)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)),
        ],
      ),
    );
  }
}
