import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/region_model.dart';
import '../repositories/player_repository.dart';
import '../models/player_model.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/player_card.dart';

/// Real destination for a Discover region tap — queries approved players
/// whose country falls in the tapped Region's country list and lists them
/// with the same PlayerCard used on the main feed.
class RegionDetailScreen extends StatefulWidget {
  final Region region;
  const RegionDetailScreen({super.key, required this.region});

  @override
  State<RegionDetailScreen> createState() => _RegionDetailScreenState();
}

class _RegionDetailScreenState extends State<RegionDetailScreen> {
  final PlayerRepository _repo = PlayerRepository();
  late Future<List<Player>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getApprovedPlayersByCountries(widget.region.countries);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getApprovedPlayersByCountries(widget.region.countries);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: Text('${widget.region.flagEmoji}  ${widget.region.name}', style: AppTheme.display(20)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Player>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.green));
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: '⚠️',
                title: 'Something went wrong',
                description: 'Could not load players for ${widget.region.name}. Pull down to retry.',
              );
            }
            final players = snapshot.data ?? [];
            if (players.isEmpty) {
              return EmptyState(
                icon: widget.region.flagEmoji,
                title: 'No players yet',
                description: 'No approved submissions from ${widget.region.name} yet — check back soon.',
              );
            }
            return RefreshIndicator(
              color: AppColors.green,
              onRefresh: _refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: players.length,
                itemBuilder: (context, i) => PlayerCard(player: players[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}
