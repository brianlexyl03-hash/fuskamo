import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/position_constants.dart';
import '../models/player_model.dart';
import '../models/scout_model.dart';
import '../repositories/player_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/player_card.dart';
import '../widgets/scout_card.dart';
import '../repositories/social_repository.dart';

/// Real destination for the feed header's search icon — searches
/// approved players and verified scouts by name in parallel, debounced so
/// it doesn't fire a query on every keystroke. Advanced filters (position,
/// age range) apply to the player search only — scouts have no equivalent
/// fields to filter on.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _playerRepo = PlayerRepository();
  final _scoutRepo = ScoutRepository();
  final _socialRepo = SocialRepository();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Player> _players = [];
  List<Scout> _scouts = [];
  List<Map<String,dynamic>> _universal = [];
  bool _loading = false;
  bool _searched = false;

  PlayerPosition? _positionFilter;
  RangeValues _ageRange = const RangeValues(10, 45);
  bool _filtersOpen = false;

  bool get _ageRangeIsDefault => _ageRange.start <= 10 && _ageRange.end >= 45;
  bool get _hasActiveFilters => _positionFilter != null || !_ageRangeIsDefault;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty && !_hasActiveFilters) {
      setState(() {
        _players = [];
        _scouts = [];
        _universal = [];
        _searched = false;
      });
      return;
    }

    setState(() => _loading = true);
    final results = await Future.wait([
      _playerRepo.searchApprovedPlayers(
        trimmed,
        position: _positionFilter,
        minAge: _ageRangeIsDefault ? null : _ageRange.start.round(),
        maxAge: _ageRangeIsDefault ? null : _ageRange.end.round(),
      ),
      // Filters are player-only — scouts still just match on typed name.
      trimmed.isEmpty
          ? Future<List<Scout>>.value(const [])
          : _scoutRepo.searchVerifiedScouts(trimmed),
      trimmed.isEmpty ? Future<List<Map<String,dynamic>>>.value(const []) : _socialRepo.search(trimmed),
    ]);
    if (!mounted) return;
    setState(() {
      _players = results[0] as List<Player>;
      _scouts = results[1] as List<Scout>;
      _universal = results[2] as List<Map<String,dynamic>>;
      _loading = false;
      _searched = true;
    });
  }

  void _clearFilters() {
    setState(() {
      _positionFilter = null;
      _ageRange = const RangeValues(10, 45);
    });
    _runSearch(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: AppTheme.body(15),
          decoration: const InputDecoration(
            hintText: 'Search people, players, clubs, groups, posts…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _hasActiveFilters ? AppColors.green : AppColors.sub,
            ),
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_filtersOpen) _buildFilterPanel(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Position', style: AppTheme.body(11, color: AppColors.sub)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _positionChip(null, 'All'),
              ...PlayerPosition.values.map((p) => _positionChip(p, p.label)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Age: ${_ageRange.start.round()}–${_ageRange.end.round()}',
            style: AppTheme.body(11, color: AppColors.sub),
          ),
          RangeSlider(
            values: _ageRange,
            min: 10,
            max: 45,
            divisions: 35,
            activeColor: AppColors.green,
            labels: RangeLabels('${_ageRange.start.round()}', '${_ageRange.end.round()}'),
            onChanged: (v) => setState(() => _ageRange = v),
            onChangeEnd: (_) => _runSearch(_controller.text),
          ),
          if (_hasActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearFilters,
                child: Text('Clear filters', style: AppTheme.body(12, color: AppColors.red)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _positionChip(PlayerPosition? position, String label) {
    final selected = _positionFilter == position;
    return ChoiceChip(
      label: Text(label, style: AppTheme.body(12, color: selected ? AppColors.black : AppColors.text)),
      selected: selected,
      selectedColor: AppColors.green,
      backgroundColor: AppColors.surface,
      onSelected: (_) {
        setState(() => _positionFilter = position);
        _runSearch(_controller.text);
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    if (!_searched) {
      return const EmptyState(
        icon: '🔎',
        title: 'Search FUSKAMO',
        description: 'Find a player by name, or use filters for position/age with no name at all.',
      );
    }
    if (_players.isEmpty && _scouts.isEmpty && _universal.isEmpty) {
      return const EmptyState(
        icon: '🔎',
        title: 'No results',
        description: 'Try a different spelling, a shorter name, or wider filters.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_universal.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text('EVERYTHING', style: AppTheme.display(16, color: AppColors.green))),
          ..._universal.map((r) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(backgroundColor: AppColors.surface, child: Icon(r['kind']=='group'?Icons.groups:r['kind']=='reel'?Icons.movie_creation_outlined:r['kind']=='post'?Icons.article_outlined:Icons.person_outline, color: AppColors.green)),
            title: Text('${r['title'] ?? ''}'),
            subtitle: Text('${r['kind'] ?? ''} · ${r['subtitle'] ?? ''}'),
            trailing: (r['verified']==true) ? const Icon(Icons.verified, color: AppColors.green, size: 18) : null,
          )),
        ],
        if (_players.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('PLAYERS', style: AppTheme.display(16, color: AppColors.green)),
          ),
          ..._players.map((p) => PlayerCard(player: p)),
        ],
        if (_scouts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('SCOUTS', style: AppTheme.display(16, color: AppColors.green)),
          ),
          ..._scouts.map((s) => ScoutCard(scout: s)),
        ],
      ],
    );
  }
}
