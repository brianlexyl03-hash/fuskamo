import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../notifications/push_notification_service.dart';
import '../providers/auth_provider.dart';
import '../repositories/notification_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Real read/write against `notification_preferences` (see
/// notification_service.dart). The push toggle has an immediate, real
/// effect — see PushNotificationService.registerTokenForCurrentUser(),
/// which now checks this before registering a device token. Email/SMS are
/// honestly labeled: the preference is recorded for when those channels
/// exist, but backend/src/email and backend/src/notifications/smsService.js
/// aren't triggered by anything yet (see backend/README.md), so toggling
/// them off has nothing to actually silence right now.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final _repo = NotificationRepository();
  bool _loading = true;
  bool _push = true;
  bool _email = true;
  bool _sms = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    final prefs = await _repo.getPreferences(userId);
    setState(() {
      _push = prefs['push'] ?? true;
      _email = prefs['email'] ?? true;
      _sms = prefs['sms'] ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    await _repo.updatePreferences(userId, push: _push, email: _email, sms: _sms);
    // Immediately apply the push toggle rather than waiting for the next
    // app restart or token refresh to notice.
    if (_push) {
      await PushNotificationService.instance.registerTokenForCurrentUser();
    } else {
      await PushNotificationService.instance.unregisterToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('NOTIFICATIONS', style: AppTheme.display(20))),
      body: SafeArea(
        child: auth.status != AuthStatus.signedIn
            ? const EmptyState(
                icon: '🔔',
                title: 'Sign in required',
                description: 'Notification preferences are tied to your account.',
              )
            : _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SwitchListTile(
                        activeColor: AppColors.green,
                        title: Text('Push notifications', style: AppTheme.body(14)),
                        subtitle: Text(
                          'Approvals, boosts, and activity on this device',
                          style: AppTheme.body(11, color: AppColors.sub),
                        ),
                        value: _push,
                        onChanged: (v) {
                          setState(() => _push = v);
                          _save();
                        },
                      ),
                      SwitchListTile(
                        activeColor: AppColors.green,
                        title: Text('Email', style: AppTheme.body(14)),
                        subtitle: Text(
                          'Not sent yet — recorded for when this is wired up',
                          style: AppTheme.body(11, color: AppColors.muted),
                        ),
                        value: _email,
                        onChanged: (v) {
                          setState(() => _email = v);
                          _save();
                        },
                      ),
                      SwitchListTile(
                        activeColor: AppColors.green,
                        title: Text('SMS', style: AppTheme.body(14)),
                        subtitle: Text(
                          'Not sent yet — recorded for when this is wired up',
                          style: AppTheme.body(11, color: AppColors.muted),
                        ),
                        value: _sms,
                        onChanged: (v) {
                          setState(() => _sms = v);
                          _save();
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}
