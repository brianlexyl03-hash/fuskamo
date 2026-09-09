import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../services/deep_link_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text('NOTIFICATIONS', style: AppTheme.display(20)),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationProvider>().markAllRead(),
            child: Text('Mark all read', style: AppTheme.body(12, color: AppColors.green)),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.notifications.isEmpty) {
              return const EmptyState(
                icon: '🔔',
                title: 'No notifications yet',
                description: 'Updates on your submissions and scout activity will show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, i) {
                final n = provider.notifications[i];
                return _NotificationTile(notification: n);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        if (!notification.read) context.read<NotificationProvider>().markRead(notification.id);
        final link=notification.deepLink;
        if(link!=null){ final target=DeepLinkService.parse(link); if(target!=null) context.push(link); }
      },
      leading: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: notification.read ? Colors.transparent : AppColors.green,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        notification.title,
        style: AppTheme.body(14, weight: notification.read ? FontWeight.normal : FontWeight.w700),
      ),
      subtitle: notification.body != null
          ? Text(notification.body!, style: AppTheme.body(12, color: AppColors.sub))
          : null,
      trailing: notification.createdAt != null
          ? Text(
              '${notification.createdAt!.day}/${notification.createdAt!.month}',
              style: AppTheme.body(10, color: AppColors.muted),
            )
          : null,
    );
  }
}
