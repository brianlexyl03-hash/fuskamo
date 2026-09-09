import 'package:flutter/material.dart';
import '../repositories/messaging_repository.dart';
import '../screens/conversation_screen.dart';

class MessagingLauncher {
  static Future<void> open(BuildContext context, String? userId) async {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This account is not linked to a FUSKAMO profile yet.')));
      return;
    }
    final repo = MessagingRepository();
    try {
      final profile = await repo.getProfile(userId);
      if (!context.mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This person has not activated messaging yet.')));
        return;
      }
      final id = await repo.getOrCreateConversation(userId);
      if (!context.mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: id, other: profile)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Messaging unavailable: $e')));
    }
  }
}
