import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/group_provider.dart';
import '../theme/app_theme.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  final _avatar = TextEditingController();
  String _category = 'General Football';
  String _privacy = 'public';
  bool _approval = false;
  bool _busy = false;
  final _categories = const ['General Football','Premier League','La Liga','Serie A','Bundesliga','Kenyan Football','African Football','Women\'s Football','Youth Football','Scouting','Transfers','Clubs','Players','National Teams'];

  @override void dispose() { _name.dispose(); _slug.dispose(); _description.dispose(); _rules.dispose(); _avatar.dispose(); super.dispose(); }
  String _slugify(String v) => v.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-').replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final g = await context.read<GroupProvider>().create(
      name: _name.text.trim(), slug: _slugify(_slug.text.isEmpty ? _name.text : _slug.text),
      description: _description.text.trim(), category: _category, privacy: _privacy,
      avatarUrl: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
      joinApproval: _approval, rules: _rules.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (g == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create the group. Check the name and slug.'))); return; }
    Navigator.pop(context, g);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('CREATE GROUP', style: AppTheme.display(22))),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(18), children: [
      Text('Build your football community', style: AppTheme.display(30)),
      const SizedBox(height: 6),
      Text('Anyone with an account can create a group. You become the first owner and host.', style: AppTheme.body(13, color: AppColors.sub)),
      const SizedBox(height: 22),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Group name'), validator: (v) => v == null || v.trim().length < 2 ? 'Enter a group name' : null, onChanged: (v) { if (_slug.text.isEmpty) _slug.text = _slugify(v); }),
      const SizedBox(height: 12),
      TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Username / slug', prefixText: '@'), validator: (v) => v == null || !RegExp(r'^[a-z0-9][a-z0-9_-]{2,39}$').hasMatch(_slugify(v)) ? 'Use 3–40 lowercase letters, numbers, _ or -' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
      const SizedBox(height: 12),
      TextFormField(controller: _rules, maxLines: 6, maxLength: 5000, decoration: const InputDecoration(labelText: 'Group rules', hintText: 'Be respectful\nNo spam\nNo harassment', alignLabelWithHint: true)),
      const SizedBox(height: 6),
      Text('Members will see these rules before they join.', style: AppTheme.body(11, color: AppColors.sub)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'Category'), items: _categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _category = v ?? _category)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _privacy, decoration: const InputDecoration(labelText: 'Privacy'), items: const [
        DropdownMenuItem(value: 'public', child: Text('Public — anyone can join')),
        DropdownMenuItem(value: 'private', child: Text('Private — approval required')),
        DropdownMenuItem(value: 'secret', child: Text('Secret — invite only')),
      ], onChanged: (v) => setState(() => _privacy = v ?? _privacy)),
      if (_privacy == 'private') SwitchListTile(contentPadding: EdgeInsets.zero, value: _approval, onChanged: (v) => setState(() => _approval = v), title: const Text('Require host approval'), subtitle: const Text('People see the group but wait for staff approval.')),
      if (_privacy == 'secret') Padding(padding: const EdgeInsets.only(top: 8), child: Text('Secret groups do not appear in recommendations. Members can enter only through an active invite.', style: AppTheme.body(12, color: AppColors.amber))),
      const SizedBox(height: 12),
      TextFormField(controller: _avatar, decoration: const InputDecoration(labelText: 'Group avatar URL (optional)')),
      const SizedBox(height: 22),
      SizedBox(height: 50, child: ElevatedButton(onPressed: _busy ? null : _create, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black)) : const Text('CREATE GROUP'))),
    ])),
  );
}
