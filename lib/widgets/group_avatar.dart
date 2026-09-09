import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/group_model.dart';

class GroupAvatar extends StatelessWidget {
  final FuskamoGroup group;
  final double size;
  const GroupAvatar({super.key, required this.group, this.size = 58});
  @override
  Widget build(BuildContext context) {
    if (group.avatarUrl != null && group.avatarUrl!.isNotEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: Image.network(group.avatarUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initials()));
    }
    return _initials();
  }
  Widget _initials() => Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .14), borderRadius: BorderRadius.circular(size * .22), border: Border.all(color: AppColors.green.withValues(alpha: .35))), child: Text(group.initials, style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w900, fontSize: size * .28)));
}
