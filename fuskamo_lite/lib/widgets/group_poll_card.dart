import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/group_model.dart';
import '../theme/app_theme.dart';

class GroupPollCard extends StatelessWidget {
  final GroupPoll poll;
  final Future<void> Function(String optionId) onVote;
  final bool canPin;
  final Future<void> Function()? onTogglePin;
  const GroupPollCard({super.key, required this.poll, required this.onVote, this.canPin = false, this.onTogglePin});

  @override
  Widget build(BuildContext context) {
    final total = poll.options.fold<int>(0, (a, b) => a + b.votes);
    return Container(margin: const EdgeInsets.fromLTRB(14, 8, 14, 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: poll.isPinned ? AppColors.green : AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(poll.question, style: AppTheme.display(20))), if (poll.isPinned) const Icon(Icons.push_pin, size: 18, color: AppColors.green), if (canPin && onTogglePin != null) IconButton(tooltip: poll.isPinned ? 'Unpin poll' : 'Pin poll', onPressed: onTogglePin, icon: Icon(poll.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 19, color: AppColors.green))]),
      const SizedBox(height: 12),
      ...poll.options.map((o) => Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(onTap: () => onVote(o.id), borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(color: o.voted ? AppColors.green.withValues(alpha: .16) : AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: o.voted ? AppColors.green : AppColors.border)), child: Row(children: [Expanded(child: Text(o.label, style: AppTheme.body(14, weight: FontWeight.w700))), Text('${o.votes}', style: AppTheme.body(12, color: AppColors.sub))]))))),
      Text('$total votes', style: AppTheme.body(12, color: AppColors.sub)),
    ]));
  }
}
