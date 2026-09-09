import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/group_model.dart';
import '../theme/app_theme.dart';
import 'group_avatar.dart';

class GroupCard extends StatelessWidget {
  final FuskamoGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final bool showJoin;
  const GroupCard({super.key, required this.group, this.onTap, this.onJoin, this.showJoin = false});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(children: [
    GroupAvatar(group: group, size: 62), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Flexible(child: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(20))), if (group.verified) ...[const SizedBox(width: 5), const Icon(Icons.verified, size: 17, color: AppColors.green)]]),
      const SizedBox(height: 4), Text('${group.hostCount} hosts · ${group.memberCount} members', style: AppTheme.body(12, color: AppColors.sub)),
      if ((group.latestMessage ?? '').isNotEmpty) ...[const SizedBox(height: 6), Text(group.latestMessage!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12))],
      const SizedBox(height: 5), Text(group.category, style: AppTheme.body(11, color: AppColors.green)),
    ])), const SizedBox(width: 8),
    if (showJoin) TextButton(onPressed: onJoin, child: Text('JOIN', style: AppTheme.display(15, color: AppColors.green)))
    else if (group.unreadCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(18)), child: Text(group.unreadCount > 99 ? '99+' : '${group.unreadCount}', style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w900)))
    else const Icon(Icons.chevron_right, color: AppColors.sub),
  ])));
}
