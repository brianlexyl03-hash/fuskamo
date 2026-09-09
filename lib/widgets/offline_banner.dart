import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../network/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Thin bar that appears above the tab content whenever ConnectivityService
/// reports no network — the concrete, visible payoff of wiring up
/// connectivity_plus instead of leaving it as a dead class nothing calls.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.onStatusChange,
      initialData: ConnectivityService.instance.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: online ? 0 : 28,
          width: double.infinity,
          color: AppColors.red,
          alignment: Alignment.center,
          child: online
              ? null
              : Text(
                  'No connection — showing cached results',
                  style: AppTheme.body(11, color: AppColors.black, weight: FontWeight.bold),
                ),
        );
      },
    );
  }
}
