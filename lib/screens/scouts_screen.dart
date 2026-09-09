import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../localisation/app_localisations.dart';
import '../providers/player_provider.dart'; // LoadState
import '../providers/scout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/scout_card.dart';

class ScoutsScreen extends StatefulWidget {
  const ScoutsScreen({super.key});

  @override
  State<ScoutsScreen> createState() => _ScoutsScreenState();
}

class _ScoutsScreenState extends State<ScoutsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoutProvider>().loadScouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('scouts_title'), style: AppTheme.display(30)),
            const SizedBox(height: 4),
            Text(context.t('scouts_subtitle'), style: AppTheme.body(12, color: AppColors.sub)),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<ScoutProvider>(
                builder: (context, provider, _) {
                  if (provider.state == LoadState.loading) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.green));
                  }
                  if (provider.scouts.isEmpty) {
                    return const EmptyState(
                      icon: '🕸',
                      title: 'No verified scouts yet',
                      description: 'Verified scouts and agents will be listed here as they join.',
                    );
                  }
                  return ListView.builder(
                    itemCount: provider.scouts.length,
                    itemBuilder: (context, i) => ScoutCard(scout: provider.scouts[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
