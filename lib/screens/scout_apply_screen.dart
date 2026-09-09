import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../helpers/toast_helper.dart';
import '../repositories/scout_repository.dart';
import '../theme/app_theme.dart';
import '../validators/form_validators.dart';

/// Before this, the only way to become a listed scout was someone hand-
/// inserting a row into Supabase — there was no application path at all.
/// Submits unverified; shows up in the Scouts queue of admin-web/.
class ScoutApplyScreen extends StatefulWidget {
  const ScoutApplyScreen({super.key});

  @override
  State<ScoutApplyScreen> createState() => _ScoutApplyScreenState();
}

class _ScoutApplyScreenState extends State<ScoutApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _orgCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _repo = ScoutRepository();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orgCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final id = await _repo.applyAsScout(
      name: _nameCtrl.text.trim(),
      organization: _orgCtrl.text.trim().isEmpty ? null : _orgCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (id != null) {
      ToastHelper.show(context, 'Application submitted for review');
      Navigator.of(context).pop();
    } else {
      ToastHelper.show(context, 'Not connected to Supabase yet — see README');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(title: Text('APPLY AS SCOUT', style: AppTheme.display(20))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Applications are reviewed before you appear as a verified scout.',
                  style: AppTheme.body(12, color: AppColors.sub),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => FormValidators.requiredText(v, fieldName: 'Name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _orgCtrl,
                  decoration: const InputDecoration(labelText: 'Club / Agency / Organization'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: FormValidators.optionalEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp / Phone'),
                  validator: FormValidators.optionalPhone,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: Text(_submitting ? 'SUBMITTING…' : 'SUBMIT APPLICATION'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
