import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

/// Real playback for the video clips players attach when submitting (see
/// upload_screen.dart / PlayerService.submitPlayer). Before this, video_url
/// was stored on every submission and never once played anywhere in the
/// app — this is the other end of that pipe.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String playerName;

  const VideoPlayerScreen({super.key, required this.videoUrl, required this.playerName});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.playerName, style: AppTheme.display(18)),
      ),
      body: Center(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this video. It may still be processing, or the link has expired.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(13, color: AppColors.sub),
                ),
              )
            : _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.green),
      ),
      floatingActionButton: _controller.value.isInitialized
          ? FloatingActionButton(
              backgroundColor: AppColors.green,
              onPressed: () => setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              }),
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppColors.black,
              ),
            )
          : null,
    );
  }
}
