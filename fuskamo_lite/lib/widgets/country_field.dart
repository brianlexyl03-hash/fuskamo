import 'package:flutter/material.dart';
import '../services/backend_api_service.dart';
import '../theme/app_theme.dart';

/// Replaces free-text country entry with an autocomplete sourced from
/// GET /external/countries — a real backend endpoint that existed
/// (documented in docs/api.md as being "for the submit form's country
/// field") but nothing ever actually called until now. Free text let
/// submissions drift ("kenya" / "Kenya " / "KE"), silently breaking
/// Discover's region filtering, which matches on exact country name
/// strings (see models/region_model.dart).
///
/// If the countries API call fails (backend down, no network), this
/// falls back to a plain text field rather than blocking submission —
/// exact-match filtering degrading gracefully beats not being able to
/// submit at all.
class CountryField extends StatefulWidget {
  final TextEditingController controller;
  const CountryField({super.key, required this.controller});

  @override
  State<CountryField> createState() => _CountryFieldState();
}

class _CountryFieldState extends State<CountryField> {
  final _api = BackendApiService();
  List<String> _countries = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.getCountries();
      final names = rows
          .map((r) => r['name'] as String?)
          .whereType<String>()
          .toList()
        ..sort();
      if (mounted) setState(() => _countries = names);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (_countries.isEmpty)) {
      // Loading, or the live list failed — plain text keeps the form usable.
      return TextFormField(
        controller: widget.controller,
        decoration: const InputDecoration(labelText: 'Country'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Country is required' : null,
      );
    }

    return Autocomplete<String>(
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const Iterable<String>.empty();
        return _countries.where((c) => c.toLowerCase().contains(value.text.toLowerCase()));
      },
      onSelected: (selection) => widget.controller.text = selection,
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        // Keep the two controllers in sync so form submission (which reads
        // widget.controller directly) always has the latest typed/selected value.
        textController.text = widget.controller.text;
        textController.addListener(() => widget.controller.text = textController.text);
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Country'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Country is required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            height: 200,
            child: ListView(
              padding: EdgeInsets.zero,
              children: options
                  .map((o) => ListTile(
                        title: Text(o, style: AppTheme.body(14)),
                        onTap: () => onSelected(o),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
