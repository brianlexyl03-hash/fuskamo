import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Real TOTP enrollment via Supabase Auth MFA — scan the QR (or enter the
/// secret manually) in Google Authenticator/Authy/1Password, then confirm
/// with a 6-digit code to activate. See auth_service.dart's MFA methods.
class MfaSetupScreen extends StatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

enum _SetupStage { loading, showQr, verifying, done, failed }

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  _SetupStage _stage = _SetupStage.loading;
  String? _factorId;
  String? _qrData;
  String? _secret;
  String? _error;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final auth = context.read<AuthProvider>();
    final result = await auth.beginMfaEnrollment();
    if (!mounted) return;
    if (result.error != null || result.factorId == null) {
      setState(() {
        _stage = _SetupStage.failed;
        _error = result.error ?? 'Could not start 2FA setup.';
      });
      return;
    }
    setState(() {
      _factorId = result.factorId;
      _qrData = result.qrData;
      _secret = result.secret;
      _stage = _SetupStage.showQr;
    });
  }

  Future<void> _verify() async {
    final factorId = _factorId;
    if (factorId == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app');
      return;
    }

    setState(() {
      _stage = _SetupStage.verifying;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final err = await auth.completeMfaEnrollment(factorId: factorId, code: code);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _stage = _SetupStage.showQr;
        _error = err;
      });
      return;
    }

    setState(() => _stage = _SetupStage.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('SET UP 2FA', style: AppTheme.display(20))),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: _buildBody())),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _SetupStage.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.green));

      case _SetupStage.failed:
        return Center(
          child: Text(_error ?? 'Something went wrong', style: AppTheme.body(13, color: AppColors.red)),
        );

      case _SetupStage.done:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, color: AppColors.green, size: 48),
              const SizedBox(height: 12),
              Text('2FA is now on', style: AppTheme.display(20)),
              const SizedBox(height: 8),
              Text(
                "You'll be asked for a code from your authenticator app next time you sign in.",
                textAlign: TextAlign.center,
                style: AppTheme.body(13, color: AppColors.sub),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Done'),
              ),
            ],
          ),
        );

      case _SetupStage.showQr:
      case _SetupStage.verifying:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Scan this with Google Authenticator, Authy, or 1Password',
                style: AppTheme.body(13, color: AppColors.sub),
              ),
              const SizedBox(height: 16),
              if (_qrData != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white,
                    child: QrImageView(data: _qrData!, size: 200),
                  ),
                ),
              const SizedBox(height: 12),
              if (_secret != null) ...[
                Text('Can\'t scan? Enter this manually:', style: AppTheme.body(12, color: AppColors.sub)),
                const SizedBox(height: 4),
                SelectableText(
                  _secret!,
                  style: AppTheme.body(14, weight: FontWeight.w600).copyWith(fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 24),
              Text('2. Enter the 6-digit code it shows', style: AppTheme.body(13, color: AppColors.sub)),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: AppTheme.body(20).copyWith(letterSpacing: 6),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppTheme.body(12, color: AppColors.red)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _stage == _SetupStage.verifying ? null : _verify,
                  child: _stage == _SetupStage.verifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : const Text('Verify and turn on'),
                ),
              ),
            ],
          ),
        );
    }
  }
}
