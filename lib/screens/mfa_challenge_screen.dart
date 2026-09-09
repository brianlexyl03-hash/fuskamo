import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Shown automatically when AuthProvider.status == AuthStatus.mfaRequired
/// — see profile_screen.dart, which renders this instead of the signed-in
/// view until the code is accepted.
class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _codeController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await context.read<AuthProvider>().submitMfaCode(code);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.green, size: 40),
            const SizedBox(height: 12),
            Text('TWO-FACTOR CODE', style: AppTheme.display(24)),
            const SizedBox(height: 6),
            Text(
              'Enter the 6-digit code from your authenticator app.',
              style: AppTheme.body(13, color: AppColors.sub),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: AppTheme.body(24).copyWith(letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTheme.body(12, color: AppColors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                      )
                    : const Text('Verify'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: auth.busy ? null : () => context.read<AuthProvider>().signOut(),
                child: Text('Cancel and sign out', style: AppTheme.body(12, color: AppColors.sub)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
