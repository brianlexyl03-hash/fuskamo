import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/position_constants.dart';
import '../controllers/upload_form_controller.dart';
import '../helpers/toast_helper.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../validators/form_validators.dart';
import '../widgets/boost_payment_dialog.dart';
import '../widgets/country_field.dart';
import '../widgets/video_coming_soon_banner.dart';
import 'video_infrastructure_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _clubCtrl = TextEditingController();
  final _leagueCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  String? _foot;
  late UploadFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UploadFormController(context.read<PlayerProvider>());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _countryCtrl.dispose();
    _clubCtrl.dispose();
    _leagueCtrl.dispose();
    _heightCtrl.dispose();
    _strengthsCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoInfrastructureScreen()));
    return;
    /*
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) _controller.setVideo(File(file.path));
    */
  }

  Future<void> _previewAiNote() async {
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null) {
      ToastHelper.show(context, 'Enter a valid age first');
      return;
    }
    await _controller.generateAiPreview(
      name: _nameCtrl.text.trim(),
      country: _countryCtrl.text.trim(),
      age: age,
      club: _clubCtrl.text.trim().isEmpty ? null : _clubCtrl.text.trim(),
      strengths: _strengthsCtrl.text.trim().isEmpty ? null : _strengthsCtrl.text.trim(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _controller.position == null) {
      if (_controller.position == null) ToastHelper.show(context, 'Please select a position');
      return;
    }

    final ok = await _controller.submit(
      name: _nameCtrl.text.trim(),
      age: int.parse(_ageCtrl.text.trim()),
      country: _countryCtrl.text.trim(),
      club: _clubCtrl.text.trim().isEmpty ? null : _clubCtrl.text.trim(),
      strengths: _strengthsCtrl.text.trim().isEmpty ? null : _strengthsCtrl.text.trim(),
      contactEmail: _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
      league: _leagueCtrl.text.trim().isEmpty ? null : _leagueCtrl.text.trim(),
      height: int.tryParse(_heightCtrl.text.trim()),
      foot: _foot,
    );

    if (!mounted) return;
    ToastHelper.show(context, ok ? 'Player submitted for review' : 'Not connected to Supabase yet — see README');

    if (ok) {
      final playerId = _controller.lastSubmittedPlayerId;
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _ageCtrl.clear();
      _countryCtrl.clear();
      _clubCtrl.clear();
      _leagueCtrl.clear();
      _heightCtrl.clear();
      _strengthsCtrl.clear();
      _contactEmailCtrl.clear();
      _contactPhoneCtrl.clear();
      setState(() => _foot = null);
      _controller.reset();

      if (playerId != null && mounted) {
        await showDialog<bool>(
          context: context,
          builder: (_) => BoostPaymentDialog(playerId: playerId),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text('SUBMIT A PLAYER', style: AppTheme.display(28)),
                const SizedBox(height: 4),
                Text('All submissions reviewed before appearing publicly',
                    style: AppTheme.body(12, color: AppColors.sub)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Player Name'),
                  validator: (v) => FormValidators.requiredText(v, fieldName: 'Name'),
                ),
                const SizedBox(height: 14),
                Consumer<UploadFormController>(
                  builder: (context, ctrl, _) => DropdownButtonFormField<PlayerPosition>(
                    initialValue: ctrl.position,
                    decoration: const InputDecoration(labelText: 'Position'),
                    dropdownColor: AppColors.card,
                    items: PlayerPosition.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                        .toList(),
                    onChanged: ctrl.setPosition,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                        validator: FormValidators.age,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CountryField(controller: _countryCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _clubCtrl,
                  decoration: const InputDecoration(labelText: 'Current Club / Academy'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _leagueCtrl,
                  decoration: const InputDecoration(labelText: 'League (optional)'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height (cm, optional)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _foot,
                        decoration: const InputDecoration(labelText: 'Foot (optional)'),
                        dropdownColor: AppColors.card,
                        items: const [
                          DropdownMenuItem(value: 'left', child: Text('Left')),
                          DropdownMenuItem(value: 'right', child: Text('Right')),
                          DropdownMenuItem(value: 'both', child: Text('Both')),
                        ],
                        onChanged: (v) => setState(() => _foot = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _strengthsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Key Strengths'),
                ),
                const SizedBox(height: 14),
                Text('Contact (optional)', style: AppTheme.body(12, color: AppColors.sub, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'So a scout who likes what they see can actually reach you or your guardian/agent. Shown only when someone taps Contact on your card.',
                  style: AppTheme.body(11, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contactEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: FormValidators.optionalEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp / Phone'),
                  validator: FormValidators.optionalPhone,
                ),
                const SizedBox(height: 10),
                Consumer<UploadFormController>(
                  builder: (context, ctrl, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: ctrl.aiState == AiSummaryState.loading ? null : _previewAiNote,
                          icon: ctrl.aiState == AiSummaryState.loading
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                                )
                              : const Icon(Icons.auto_awesome, size: 16, color: AppColors.green),
                          label: Text('Preview AI scouting note', style: AppTheme.body(12, color: AppColors.green)),
                        ),
                      ),
                      if (ctrl.aiState == AiSummaryState.ready && ctrl.aiSummary != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(ctrl.aiSummary!, style: AppTheme.body(13, color: AppColors.sub)),
                        ),
                      if (ctrl.aiState == AiSummaryState.error && ctrl.aiError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(ctrl.aiError!, style: AppTheme.body(11, color: AppColors.red)),
                        ),
                    ],
                  ),
                ),
                const VideoComingSoonBanner(),
                const SizedBox(height: 10),
                Consumer<UploadFormController>(
                  builder: (context, ctrl, _) => GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ctrl.videoFile != null ? AppColors.green : AppColors.border,
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.upload_outlined, color: AppColors.sub),
                          const SizedBox(height: 6),
                          Text(
                            ctrl.videoFile?.path.split('/').last ?? 'Attach video clip (optional)',
                            style: AppTheme.body(13, color: ctrl.videoFile != null ? AppColors.green : AppColors.sub),
                          ),
                          const SizedBox(height: 4),
                          Text('MP4 · MOV · up to 50MB when cloud storage launches', style: AppTheme.body(10, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Consumer<UploadFormController>(
                  builder: (context, ctrl, _) => ElevatedButton(
                    onPressed: ctrl.state == SubmitState.submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: Text(ctrl.state == SubmitState.submitting ? 'SUBMITTING…' : 'SUBMIT PLAYER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
