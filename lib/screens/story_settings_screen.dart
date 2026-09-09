import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class StorySettingsScreen extends StatefulWidget {
  const StorySettingsScreen({super.key});
  @override State<StorySettingsScreen> createState() => _StorySettingsScreenState();
}

class _StorySettingsScreenState extends State<StorySettingsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  bool _loading = false;

  Future<void> _find() async {
    final q = _search.text.trim();
    if (q.isEmpty) {
      setState(() => _friends = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final db = SupabaseService.client;
      final me = db.auth.currentUser?.id;
      if (me == null) return;
      final rows = await db.from('profiles').select('user_id,display_name,username,avatar_url').ilike('display_name', '%$q%').limit(20);
      final selectedRows = await db.from('close_friends').select('friend_id').eq('owner_id', me);
      final selected = selectedRows.map((e) => e['friend_id'] as String).toSet();
      _friends = rows.map<Map<String, dynamic>>((r) {
        final m = Map<String, dynamic>.from(r);
        m['selected'] = selected.contains(m['user_id']);
        return m;
      }).toList();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle(String id, bool value) async {
    final db = SupabaseService.client;
    final me = db.auth.currentUser!.id;
    if (value) {
      await db.from('close_friends').upsert({'owner_id': me, 'friend_id': id});
    } else {
      await db.from('close_friends').delete().eq('owner_id', me).eq('friend_id', id);
    }
    await _find();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('STORY PRIVACY', style: AppTheme.display(20))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('CLOSE FRIENDS', style: AppTheme.display(24)),
          const SizedBox(height: 6),
          Text('Only people you add here can view Close Friends stories.', style: AppTheme.body(12, color: AppColors.sub)),
          const SizedBox(height: 14),
          TextField(controller: _search, onChanged: (_) => _find(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find a person')),
          const SizedBox(height: 12),
          if (_loading) const CircularProgressIndicator(),
          ..._friends.map((m) => SwitchListTile(
                title: Text(m['display_name'] ?? 'Member'),
                subtitle: Text('@${m['username'] ?? ''}'),
                value: m['selected'] == true,
                onChanged: (v) => _toggle(m['user_id'] as String, v),
              )),
        ],
      ),
    );
  }
}
