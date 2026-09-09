import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  SupabaseClient get db => SupabaseService.client;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await db.from('badge_achievements').select('id,code,name,description,icon,points').eq('active', true).order('points');
    return rows.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<bool> _earned(String id) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await db.from('profile_achievements').select('achievement_id').eq('user_id', uid).eq('achievement_id', id).maybeSingle();
    return row != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('ACHIEVEMENTS', style: AppTheme.display(21))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: AppColors.green));
          if (snap.hasError) return Center(child: Text('Achievements unavailable.\n${snap.error}', textAlign: TextAlign.center, style: AppTheme.body(12, color: AppColors.sub)));
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text('EARN RECOGNITION', style: AppTheme.display(28)),
              const SizedBox(height: 6),
              Text('Awards recognise meaningful participation. They never automatically grant a verification tick.', style: AppTheme.body(12, color: AppColors.sub)),
              const SizedBox(height: 16),
              ...rows.map((a) => FutureBuilder<bool>(
                    future: _earned(a['id'] as String),
                    builder: (context, earned) => Card(
                      color: AppColors.card,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: earned.data == true ? AppColors.green : AppColors.surface,
                          child: Text('${a['icon']}', style: TextStyle(color: earned.data == true ? AppColors.black : AppColors.green)),
                        ),
                        title: Text('${a['name']} ${earned.data == true ? '✓' : ''}'),
                        subtitle: Text(a['description'] as String, style: AppTheme.body(11, color: AppColors.sub)),
                        trailing: Text('${a['points']} pts', style: AppTheme.body(11, color: AppColors.green, weight: FontWeight.w800)),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
