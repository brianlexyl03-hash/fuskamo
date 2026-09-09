import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/scoreboard_models.dart';
import '../repositories/scoreboard_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/verified_badge.dart';
import 'public_profile_screen.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});
  @override State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  final _repo = ScoreboardRepository();
  String _category = 'global';
  late Future<List<ScoreboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ScoreboardEntry>> _load() async {
    await _repo.refreshMyScore();
    return _repo.load(category: _category);
  }

  void _change(String value) {
    setState(() {
      _category = value;
      _future = _repo.load(category: value);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('FUSKAMO SCOREBOARD', style: AppTheme.display(21))),
        body: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async => setState(() => _future = _load()),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Text('THE SCOREBOARD', style: AppTheme.display(30)),
              const SizedBox(height: 4),
              Text(
                'A transparent reputation board — not a popularity contest. Trust, quality, authentic recognition, achievements and recent momentum all matter.',
                style: AppTheme.body(12, color: AppColors.sub),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Text(
                  'A verification tick never gives an account a free pass to #1. Buying boosts cannot buy scoreboard points. Suspicious reputation signals are capped and penalized.',
                  style: AppTheme.body(11, color: AppColors.sub),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['global', 'player', 'scout', 'club', 'coach', 'rising', 'trusted'].map((value) => _CategoryChip(value: value, label: value == 'global' ? 'GLOBAL' : value == 'rising' ? 'RISING' : value == 'trusted' ? 'TRUSTED' : '${value.toUpperCase()}S', active: _category == value, onTap: () => _change(value))).toList(),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<ScoreboardEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                  if (snapshot.hasError) return Text('Scoreboard unavailable: ${snapshot.error}', style: AppTheme.body(12, color: AppColors.red));
                  final rows = snapshot.data ?? const <ScoreboardEntry>[];
                  if (rows.isEmpty) return Text('No ranked profiles yet.', style: AppTheme.body(12, color: AppColors.sub));
                  return Column(children: rows.map((e) => _entry(e)).toList());
                },
              ),
            ],
          ),
        ),
      );

  Widget _entry(ScoreboardEntry e) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: e.rank <= 3 ? AppColors.surface : AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: e.userId))), child: Row(children: [
          SizedBox(width: 34, child: Text('#${e.rank}', style: AppTheme.display(17, color: e.rank <= 3 ? AppColors.green : AppColors.sub))),
          CircleAvatar(radius: 22, backgroundImage: e.avatarUrl != null && e.avatarUrl!.isNotEmpty ? NetworkImage(e.avatarUrl!) : null, backgroundColor: AppColors.surface, child: e.avatarUrl == null || e.avatarUrl!.isEmpty ? Text(e.displayName.isEmpty ? '?' : e.displayName[0].toUpperCase()) : null),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text(e.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, weight: FontWeight.w800))), const SizedBox(width: 5), VerifiedBadge(badgeType: e.badgeType, verified: e.verified, size: 15)]),
            Text('@${e.username} · ${e.role.toUpperCase()}', style: AppTheme.body(10, color: AppColors.sub)),
            const SizedBox(height: 4),
            Text('${e.followers} followers · ${e.likes} likes · ${e.achievementPoints} award pts', style: AppTheme.body(9, color: AppColors.sub)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(e.score.toStringAsFixed(1), style: AppTheme.display(18)), Text('SCORE', style: AppTheme.body(8, color: AppColors.sub)), if (e.momentum > 0) Text('↗ ${e.momentum.toStringAsFixed(0)}', style: AppTheme.body(9, color: AppColors.green))]),
        ])),
      );
}

class _CategoryChip extends StatelessWidget {
  final String value;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CategoryChip({required this.value, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: active ? AppColors.green : AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppColors.black : AppColors.text))),
    );
  }
}
