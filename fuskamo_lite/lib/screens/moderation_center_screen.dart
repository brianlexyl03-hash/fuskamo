import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({super.key});
  @override State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> {
  List<Map<String, dynamic>> reports = [];
  bool loading = true;
  String? error;
  SupabaseClient get db => SupabaseService.client;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await db.from('moderation_cases').select('id,target_type,target_id,reason,description,severity,status,created_at,resolution').inFilter('status', ['open','triaged','investigating','appealed']).order('severity', ascending: false).order('created_at', ascending: false).limit(100);
      reports = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
      error = null;
    } catch (_) { error = 'You need content moderation permission to access this center.'; }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _resolve(Map<String, dynamic> report, String status) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(status == 'actioned' ? 'Action report' : 'Dismiss report'), content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Resolution')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('SAVE'))]));
    controller.dispose();
    if (reason == null) return;
    try { await db.rpc('resolve_moderation_case', params: {'p_case': report['id'], 'p_status': status, 'p_resolution': reason}); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update case: $e'))); }
  }

  @override Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator(color: AppColors.green));
    } else if (error != null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: AppTheme.body(14, color: AppColors.red))));
    } else if (reports.isEmpty) {
      body = Center(child: Text('No open moderation cases.', style: AppTheme.body(14, color: AppColors.sub)));
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reports.length,
        itemBuilder: (_, i) {
          final r = reports[i];
          return Card(color: AppColors.card, child: ListTile(
            title: Text('${r['target_type']} · ${r['reason']} · severity ${r['severity']}'),
            subtitle: Text('${r['description'] ?? ''}\n${r['created_at'] ?? ''}'),
            isThreeLine: true,
            leading: const Icon(Icons.flag_outlined, color: AppColors.red),
            trailing: PopupMenuButton<String>(onSelected: (v) => _resolve(r, v), itemBuilder: (_) => const [PopupMenuItem(value: 'actioned', child: Text('Action')), PopupMenuItem(value: 'dismissed', child: Text('Dismiss'))]),
          ));
        },
      );
    }
    return Scaffold(backgroundColor: AppColors.black, appBar: AppBar(title: const Text('MODERATION CENTER'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]), body: body);
  }
}
