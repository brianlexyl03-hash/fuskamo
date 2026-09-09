import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import 'toast_helper.dart';

/// Real contact actions — replaces the fake "Message sent to scout" /
/// "Player saved" toasts that used to sit on PlayerCard's Contact button.
/// Shows a bottom sheet with whichever channels the row actually has data
/// for (email / phone / WhatsApp), or an honest "no contact info on file"
/// message when it has none — never a fake success state.
class ContactLauncher {
  static Future<void> show(
    BuildContext context, {
    required String subjectName,
    String? email,
    String? phone,
  }) async {
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;

    if (!hasEmail && !hasPhone) {
      ToastHelper.show(context, 'No contact info on file for $subjectName yet');
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Contact $subjectName', style: AppTheme.display(18)),
            ),
            if (hasEmail)
              ListTile(
                leading: const Icon(Icons.email_outlined, color: AppColors.green),
                title: Text('Email', style: AppTheme.body(14)),
                subtitle: Text(email, style: AppTheme.body(12, color: AppColors.sub)),
                onTap: () => _launch(context, Uri(
                  scheme: 'mailto',
                  path: email,
                  queryParameters: {'subject': 'FUSKAMO — regarding $subjectName'},
                )),
              ),
            if (hasPhone) ...[
              ListTile(
                leading: const Icon(Icons.chat_outlined, color: AppColors.green),
                title: Text('WhatsApp', style: AppTheme.body(14)),
                subtitle: Text(phone, style: AppTheme.body(12, color: AppColors.sub)),
                onTap: () => _launch(
                  context,
                  Uri.parse('https://wa.me/${_digitsOnly(phone)}?text=${Uri.encodeComponent('Hi, I found $subjectName on FUSKAMO.')}'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.call_outlined, color: AppColors.green),
                title: Text('Call', style: AppTheme.body(14)),
                subtitle: Text(phone, style: AppTheme.body(12, color: AppColors.sub)),
                onTap: () => _launch(context, Uri(scheme: 'tel', path: phone)),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

  static Future<void> _launch(BuildContext context, Uri uri) async {
    Navigator.of(context).pop();
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ToastHelper.show(context, 'Could not open that — is a matching app installed?');
    }
  }
}
