import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/position_constants.dart';
import '../helpers/toast_helper.dart';
import '../models/scout_model.dart';
import '../repositories/scout_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Sets scouts.preferred_positions/preferred_countries/age_min/age_max/
/// preferred_foot/preferred_height_min — the columns discoveryEngine.js's
/// calculateScore() reads. Without this screen there was no way for a
/// scout to actually configure the "brain" the ranking engine is supposed
/// to be personalizing for them; every feed would score as if they had no
/// preferences at all.
class ScoutPreferencesScreen extends StatefulWidget {
  const ScoutPreferencesScreen({super.key});

  @override
  State<ScoutPreferencesScreen> createState() => _ScoutPreferencesScreenState();
}

class _ScoutPreferencesScreenState extends State<ScoutPreferencesScreen> {
  final _repo = ScoutRepository();
  final _countriesCtrl = TextEditingController();
  final _ageMinCtrl = TextEditingController();
  final _ageMaxCtrl = TextEditingController();
  final _heightMinCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Scout? _scout;
  final Set<PlayerPosition> _positions = {};
  String? _foot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countriesCtrl.dispose();
    _ageMinCtrl.dispose();
    _ageMaxCtrl.dispose();
    _heightMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scout = await _repo.fetchMyScout();
    if (!mounted) return;
    setState(() {
      _scout = scout;
      _loading = false;
      if (scout != null) {
        _positions.addAll(scout.preferredPositions.map(PlayerPositionX.fromDbValue));
        _countriesCtrl.text = scout.preferredCountries.join(', ');
        _ageMinCtrl.text = scout.ageMin?.toString() ?? '';
        _ageMaxCtrl.text = scout.ageMax?.toString() ?? '';
        _heightMinCtrl.text = scout.preferredHeightMin?.toString() ?? '';
        _foot = scout.preferredFoot;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await _repo.updateMyPreferences(
      preferredPositions: _positions.map((p) => p.dbValue).toList(),
      preferredCountries: _countriesCtrl.text
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList(),
      ageMin: int.tryParse(_ageMinCtrl.text.trim()),
      ageMax: int.tryParse(_ageMaxCtrl.text.trim()),
      preferredFoot: _foot,
      preferredHeightMin: int.tryParse(_heightMinCtrl.text.trim()),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ToastHelper.show(
      context,
      ok ? 'Preferences saved' : 'Could not save — check your connection',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Discovery preferences', style: AppTheme.display(18))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.green))
            : _scout == null
                ? const EmptyState(
                    icon: '🧭',
                    title: 'No scout profile yet',
                    description: 'Apply as a scout from the Profile tab first.',
                  )
                : _scout!.verified
                    ? _buildForm()
                    : const EmptyState(
                        icon: '⏳',
                        title: 'Application pending',
                        description:
                            'Your scout application is still under review. Preferences unlock once verified.',
                      ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('These tune your "For you" feed — they never hide a player, '
            'they just re-rank the results.',
            style: AppTheme.body(12, color: AppColors.sub)),
        const SizedBox(height: 18),
        Text('Positions', style: AppTheme.body(13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PlayerPosition.values.map((p) {
            final selected = _positions.contains(p);
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (v) => setState(() => v ? _positions.add(p) : _positions.remove(p)),
              selectedColor: AppColors.green.withValues(alpha: 0.18),
              labelStyle: AppTheme.body(12, color: selected ? AppColors.green : AppColors.sub),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: selected ? AppColors.green : AppColors.border),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text('Countries', style: AppTheme.body(13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _countriesCtrl,
          style: AppTheme.body(14),
          decoration: const InputDecoration(hintText: 'e.g. Kenya, Nigeria, Ghana'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Min age', style: AppTheme.body(13, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ageMinCtrl,
                    keyboardType: TextInputType.number,
                    style: AppTheme.body(14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Max age', style: AppTheme.body(13, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ageMaxCtrl,
                    keyboardType: TextInputType.number,
                    style: AppTheme.body(14),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Preferred foot', style: AppTheme.body(13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['left', 'right', 'both'].map((f) {
            final selected = _foot == f;
            return ChoiceChip(
              label: Text(f),
              selected: selected,
              onSelected: (v) => setState(() => _foot = v ? f : null),
              selectedColor: AppColors.green.withValues(alpha: 0.18),
              labelStyle: AppTheme.body(12, color: selected ? AppColors.green : AppColors.sub),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: selected ? AppColors.green : AppColors.border),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text('Min height (cm)', style: AppTheme.body(13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _heightMinCtrl,
          keyboardType: TextInputType.number,
          style: AppTheme.body(14),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: Text(_saving ? 'Saving…' : 'Save preferences'),
        ),
      ],
    );
  }
}
