import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});
  @override State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final _repo = MessagingRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.messageRequests();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.messageRequests());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('MESSAGE REQUESTS', style: AppTheme.display(20))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load requests.\n${snap.error}', textAlign: TextAlign.center, style: AppTheme.body(12, color: AppColors.sub)));
          }
          final rows = snap.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(children: [
                const SizedBox(height: 180),
                Center(child: Icon(Icons.mark_email_read_outlined, size: 50, color: AppColors.sub)),
                const SizedBox(height: 12),
                Center(child: Text('NO MESSAGE REQUESTS', style: AppTheme.display(18))),
                const SizedBox(height: 6),
                Center(child: Text('People who cannot start a conversation directly can appear here.', style: AppTheme.body(12, color: AppColors.sub), textAlign: TextAlign.center)),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.border),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  title: const Text('New message request'),
                  subtitle: Text('From ${r['sender_id']}\n${r['created_at']}'),
                  isThreeLine: true,
                  trailing: Wrap(spacing: 4, children: [
                    IconButton(
                      onPressed: () async {
                        await _repo.respondMessageRequest(r['id'] as String, false);
                        await _reload();
                      },
                      icon: const Icon(Icons.close, color: AppColors.red),
                    ),
                    IconButton(
                      onPressed: () async {
                        await _repo.respondMessageRequest(r['id'] as String, true);
                        await _reload();
                      },
                      icon: const Icon(Icons.check, color: AppColors.green),
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
