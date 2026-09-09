import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/group_model.dart';
import '../repositories/group_repository.dart';
import '../theme/app_theme.dart';

class GroupAdminScreen extends StatefulWidget {
  final FuskamoGroup group;
  const GroupAdminScreen({super.key, required this.group});
  @override State<GroupAdminScreen> createState() => _GroupAdminScreenState();
}

class _GroupAdminScreenState extends State<GroupAdminScreen> {
  final _repo = GroupRepository();
  late Future<List<Map<String, dynamic>>> _members;
  late Future<List<Map<String, dynamic>>> _bans;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _members = _repo.members(widget.group.id); _bans = _repo.groupBans(widget.group.id); }

  Future<void> _promote(String id, String role) async {
    await _repo.promoteMember(widget.group.id, id, role);
    if (mounted) { setState(_reload); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Member updated to $role.'))); }
  }

  Future<void> _ban(String id) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('BAN MEMBER'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('BAN')),
        ],
      ),
    );
    if (ok == true) await _repo.banMember(widget.group.id, id, reason: c.text.trim());
    c.dispose();
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('GROUP ADMIN', style: AppTheme.display(20))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(widget.group.name, style: AppTheme.display(25)),
          const SizedBox(height: 16),
          Text('MEMBERS', style: AppTheme.display(18)),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _members,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
              final members = snap.data ?? const <Map<String, dynamic>>[];
              return Column(children: members.map((m) => Card(
                color: AppColors.card,
                child: ListTile(
                  title: Text('${m['display_name'] ?? m['user_id']}'),
                  subtitle: Text('${m['role']} · joined ${m['joined_at']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'host') _promote(m['user_id'] as String, 'host');
                      if (v == 'moderator') _promote(m['user_id'] as String, 'moderator');
                      if (v == 'member') _promote(m['user_id'] as String, 'member');
                      if (v == 'ban') _ban(m['user_id'] as String);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'host', child: Text('Make host')),
                      PopupMenuItem(value: 'moderator', child: Text('Make moderator')),
                      PopupMenuItem(value: 'member', child: Text('Demote to member')),
                      PopupMenuItem(value: 'ban', child: Text('Ban')),
                    ],
                  ),
                ),
              )).toList());
            },
          ),
          const SizedBox(height: 18),
          Text('BANNED', style: AppTheme.display(18)),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _bans,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
              final bans = snap.data ?? const <Map<String, dynamic>>[];
              if (bans.isEmpty) return Text('No banned members.', style: AppTheme.body(12, color: AppColors.sub));
              return Column(children: bans.map((b) => ListTile(
                title: Text('${b['user_id']}'),
                subtitle: Text('${b['reason'] ?? ''}'),
                trailing: TextButton(onPressed: () async { await _repo.unbanMember(widget.group.id, b['user_id'] as String); if (mounted) setState(_reload); }, child: const Text('UNBAN')),
              )).toList());
            },
          ),
          const SizedBox(height: 18),
          Text('ROLE PERMISSIONS', style: AppTheme.display(18)),
          for (final role in ['host', 'moderator'])
            for (final permission in ['pin', 'delete_messages', 'create_polls', 'manage_members', 'manage_invites'])
              SwitchListTile(
                title: Text('$role · $permission'),
                value: true,
                onChanged: (v) => _repo.setGroupPermission(widget.group.id, role, permission, v),
              ),
        ],
      ),
    );
  }
}
