import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scoreboard_models.dart';
import 'supabase_service.dart';

class ScoreboardService {
  SupabaseClient get _db => SupabaseService.client;

  Future<List<ScoreboardEntry>> load({String category = 'global', int limit = 50}) async {
    final rows = await _db.rpc('get_fuskamo_scoreboard', params: {
      'p_category': category,
      'p_limit': limit,
    });
    return (rows as List)
        .map((row) => ScoreboardEntry.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> refreshMyScore() async {
    await _db.rpc('refresh_my_scoreboard_score');
  }
}
