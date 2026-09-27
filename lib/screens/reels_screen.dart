import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/video_coming_soon_banner.dart';
import 'video_infrastructure_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SocialProvider>().load());
  }

  void _create() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoInfrastructureScreen()));
  }

  @override
  Widget build(BuildContext context) => Consumer<SocialProvider>(
    builder: (context, provider, _) {
      final content = provider.reels.isEmpty
          ? ListView(children: const [VideoComingSoonBanner(), SizedBox(height: 80)])
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: provider.reels.length,
              itemBuilder: (_, index) => _ReelCard(reel: provider.reels[index]),
            );
      return Stack(
        children: [
          Positioned.fill(child: content),
          if (provider.reels.isEmpty)
            Positioned(
              right: 18,
              bottom: 18,
              child: GlassSurface.circle(
                size: 56,
                child: IconButton(onPressed: _create, icon: const Icon(Icons.add, color: Colors.white, size: 26)),
              ),
            ),
        ],
      );
    },
  );
}

class _ReelCard extends StatefulWidget {
  final SocialReel reel;
  const _ReelCard({required this.reel});
  @override State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  VideoPlayerController? _controller;
  bool liked = false;
  bool saved = false;
  bool _chromeVisible = true;
  final DateTime started = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller!.play();
        _controller!.setLooping(true);
      });
  }

  @override
  void dispose() {
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    final controller = _controller;
    if (controller != null) {
      context.read<SocialProvider>().repository.viewReel(
        widget.reel.id,
        watchMs: elapsed,
        completed: controller.value.isInitialized && controller.value.position >= controller.value.duration,
      );
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('REPORT REEL'),
        children: ['spam', 'harassment', 'impersonation', 'scam', 'hate', 'sexual', 'violence', 'other']
            .map((r) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r)))
            .toList(),
      ),
    );
    if (reason != null && mounted) {
      await context.read<SocialProvider>().repository.report(targetType: 'reel', targetId: widget.reel.id, reason: reason);
    }
  }

  Future<void> _comments() async {
    final repo = context.read<SocialProvider>().repository;
    final rows = await repo.reelComments(widget.reel.id);
    if (!mounted) return;
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: GlassSurface(
          blur: 24,
          opacity: 0.30,
          tint: AppColors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .65,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Padding(padding: const EdgeInsets.all(16), child: Text('REEL COMMENTS', style: AppTheme.display(20))),
                Expanded(
                  child: ListView(
                    children: rows.map((r) => ListTile(title: Text(r['body'] as String? ?? ''), subtitle: Text(r['author_id'] as String? ?? ''))).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Comment…'))),
                    IconButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        await repo.addReelComment(widget.reel.id, controller.text.trim());
                        controller.clear();
                      },
                      icon: const Icon(Icons.send, color: AppColors.green),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _chromeVisible = !_chromeVisible),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_controller?.value.isInitialized ?? false)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)),
          )
        else
          const Center(child: CircularProgressIndicator(color: AppColors.green)),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _chromeVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: Stack(
              children: [
                Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
                Positioned(
                  left: 18,
                  right: 90,
                  bottom: 34,
                  child: GlassSurface(
                    blur: 14,
                    opacity: 0.16,
                    borderRadius: BorderRadius.circular(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('@${widget.reel.authorId.substring(0, widget.reel.authorId.length > 8 ? 8 : widget.reel.authorId.length)}', style: AppTheme.body(14, weight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(widget.reel.caption, style: AppTheme.body(13)),
                    ]),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 70,
                  child: Column(children: [
                    GlassSurface.circle(
                      child: IconButton(
                        onPressed: () async {
                          await context.read<SocialProvider>().toggleReelLike(widget.reel.id);
                          if (mounted) setState(() => liked = !liked);
                        },
                        icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? AppColors.red : Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.reel.likeCount}', style: AppTheme.body(11)),
                    const SizedBox(height: 12),
                    GlassSurface.circle(
                      child: IconButton(onPressed: _comments, icon: const Icon(Icons.comment, color: Colors.white, size: 22)),
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.reel.commentCount}', style: AppTheme.body(11)),
                    const SizedBox(height: 12),
                    GlassSurface.circle(
                      size: 40,
                      child: IconButton(
                        onPressed: () async { await context.read<SocialProvider>().repository.saveReel(widget.reel.id); if(mounted)setState(()=>saved=!saved); },
                        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? AppColors.green : Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassSurface.circle(
                      size: 40,
                      child: IconButton(
                        onPressed: () async { await context.read<SocialProvider>().repository.shareReel(widget.reel.id); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel share recorded.'))); },
                        icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassSurface.circle(
                      size: 40,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        onSelected: (v) async { if(v=='report') await _report(); if(v=='not_interested') { await context.read<SocialProvider>().repository.reelFeedback(widget.reel.id,'not_interested'); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We will show you fewer similar reels.'))); } if(v=='hide_creator') await context.read<SocialProvider>().repository.reelFeedback(widget.reel.id,'hide_creator'); },
                        itemBuilder: (_) => const [PopupMenuItem(value:'not_interested', child: Text('Not interested')),PopupMenuItem(value:'hide_creator', child: Text('Show fewer from this creator')),PopupMenuItem(value: 'report', child: Text('Report reel'))],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
