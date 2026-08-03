import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

/// Plays a locally-stored recipe video (the ~480p copy saved on import) with
/// standard playback controls. Shows a graceful placeholder if the file is
/// missing or fails to initialise.
class RecipeVideoPlayer extends StatefulWidget {
  const RecipeVideoPlayer({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<RecipeVideoPlayer> createState() => _RecipeVideoPlayerState();
}

class _RecipeVideoPlayerState extends State<RecipeVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initializing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final file = File(widget.videoPath);
    if (!await file.exists()) {
      if (mounted) setState(() { _initializing = false; _failed = true; });
      return;
    }
    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final aspect = controller.value.aspectRatio;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        aspectRatio: aspect > 0 ? aspect : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
      );
      _videoController = controller;
      if (mounted) setState(() => _initializing = false);
    } catch (_) {
      if (mounted) setState(() { _initializing = false; _failed = true; });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radiusMd);

    if (_initializing) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: radius,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_failed || _chewieController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: radius,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded,
                    color: scheme.onSurfaceVariant),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Video unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
