import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/backend_api_service.dart';
import '../theme/app_theme.dart';

/// "Feature this submission" — a fixed-price M-Pesa boost tied to a single
/// player row. Shown right after a successful upload (see upload_screen.dart).
/// On a completed payment the backend's mpesaController marks the player
/// featured_until = now+48h (see backend/src/controllers/mpesaController.js
/// and database/migrations/008_player_boosts.sql) — PlayerService already
/// sorts featured players first, so this has a real, visible effect on the
/// feed once M-Pesa is configured server-side.
class BoostPaymentDialog extends StatefulWidget {
  final String playerId;
  static const int amountKes = 50;

  const BoostPaymentDialog({super.key, required this.playerId});

  @override
  State<BoostPaymentDialog> createState() => _BoostPaymentDialogState();
}

enum _BoostStage { form, initiating, waiting, success, failed }

class _BoostPaymentDialogState extends State<BoostPaymentDialog> {
  final _phoneController = TextEditingController();
  final _api = BackendApiService();
  _BoostStage _stage = _BoostStage.form;
  String? _error;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  static final _phoneRegex = RegExp(r'^254[17]\d{8}$');

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    final phone = _phoneController.text.trim();
    if (!_phoneRegex.hasMatch(phone)) {
      setState(() => _error = 'Enter phone as 2547XXXXXXXX or 2541XXXXXXXX');
      return;
    }

    setState(() {
      _stage = _BoostStage.initiating;
      _error = null;
    });

    try {
      final result = await _api.initiateMpesaPayment(
        phoneNumber: phone,
        amount: BoostPaymentDialog.amountKes,
        accountReference: 'BOOST-${widget.playerId}',
        transactionDesc: 'FUSKAMO submission boost',
      );
      final checkoutRequestId = result['data']?['CheckoutRequestID'] as String? ??
          result['CheckoutRequestID'] as String?;
      if (checkoutRequestId == null) throw Exception('No CheckoutRequestID in response');

      setState(() => _stage = _BoostStage.waiting);
      _pollStatus(checkoutRequestId);
    } catch (e) {
      setState(() {
        _stage = _BoostStage.failed;
        _error = 'Could not start payment: ${e.toString()}';
      });
    }
  }

  void _pollStatus(String checkoutRequestId) {
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > 20) {
        // ~60s of polling — Safaricom's callback should have landed by now.
        timer.cancel();
        if (mounted) setState(() => _stage = _BoostStage.failed);
        return;
      }
      try {
        final status = await _api.getPaymentStatus(checkoutRequestId);
        final localStatus = status['local']?['status'] as String?;
        if (localStatus == 'completed') {
          timer.cancel();
          if (mounted) setState(() => _stage = _BoostStage.success);
        } else if (localStatus == 'failed') {
          timer.cancel();
          if (mounted) setState(() => _stage = _BoostStage.failed);
        }
        // 'pending' — keep polling
      } catch (_) {
        // Transient network error while polling — keep trying until the
        // attempt cap above gives up.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Feature this submission', style: AppTheme.display(18)),
      content: SizedBox(width: 320, child: _buildBody()),
      actions: _buildActions(),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _BoostStage.form:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KES ${BoostPaymentDialog.amountKes} — appears at the top of the feed for 48 hours.',
              style: AppTheme.body(13, color: AppColors.sub),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: AppTheme.body(14),
              decoration: const InputDecoration(labelText: 'M-Pesa phone (2547XXXXXXXX)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTheme.body(12, color: AppColors.red)),
            ],
          ],
        );
      case _BoostStage.initiating:
        return const _CenteredSpinner(label: 'Sending payment request…');
      case _BoostStage.waiting:
        return const _CenteredSpinner(label: 'Check your phone and enter your M-Pesa PIN…');
      case _BoostStage.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 40),
            const SizedBox(height: 10),
            Text('Payment received — this submission is now featured.',
                textAlign: TextAlign.center, style: AppTheme.body(13)),
          ],
        );
      case _BoostStage.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 40),
            const SizedBox(height: 10),
            Text(_error ?? 'Payment did not complete.',
                textAlign: TextAlign.center, style: AppTheme.body(13)),
          ],
        );
    }
  }

  List<Widget> _buildActions() {
    switch (_stage) {
      case _BoostStage.form:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Skip')),
          ElevatedButton(onPressed: _startPayment, child: const Text('Pay')),
        ];
      case _BoostStage.initiating:
      case _BoostStage.waiting:
        return [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close'))];
      case _BoostStage.success:
        return [ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done'))];
      case _BoostStage.failed:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
          ElevatedButton(
            onPressed: () => setState(() => _stage = _BoostStage.form),
            child: const Text('Try again'),
          ),
        ];
    }
  }
}

class _CenteredSpinner extends StatelessWidget {
  final String label;
  const _CenteredSpinner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.green),
        const SizedBox(height: 14),
        Text(label, textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)),
      ],
    );
  }
}
