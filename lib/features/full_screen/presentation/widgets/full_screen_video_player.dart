import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../media_library/domain/entities/media_entity.dart';

/// Full-screen video player widget
class FullScreenVideoPlayer extends StatefulWidget {
  const FullScreenVideoPlayer({
    super.key,
    required this.media,
    required this.isPlaying,
    required this.isMuted,
    required this.isLooping,
    required this.onPositionUpdate,
    required this.onDurationUpdate,
    required this.onPlayingStateUpdate,
  });

  final MediaEntity media;
  final bool isPlaying;
  final bool isMuted;
  final bool isLooping;
  final ValueChanged<Duration> onPositionUpdate;
  final ValueChanged<Duration> onDurationUpdate;
  final ValueChanged<bool> onPlayingStateUpdate;

  @override
  State<FullScreenVideoPlayer> createState() => FullScreenVideoPlayerState();
}

class FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(FullScreenVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.media.path != oldWidget.media.path) {
      _reloadForNewMedia();
      return;
    }

    final controller = _controller;
    if (controller != null) {
      if (widget.isMuted != oldWidget.isMuted) {
        controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      }
      if (widget.isLooping != oldWidget.isLooping) {
        controller.setLooping(widget.isLooping);
      }
      if (widget.isPlaying != oldWidget.isPlaying) {
        if (widget.isPlaying) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    }
  }

  Future<void> _initializePlayer() async {
    final controller = VideoPlayerController.file(File(widget.media.path));
    _controller = controller;
    try {
      await controller.initialize();
      controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      controller.setLooping(widget.isLooping);

      controller.addListener(_onVideoUpdate);
      _onVideoUpdate();

      if (widget.isPlaying) {
        await controller.play();
      } else if (controller.value.isPlaying) {
        await controller.pause();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle initialization error
      debugPrint('Video initialization error: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onVideoUpdate() {
    if (_controller == null || !mounted) return;

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final isPlaying = _controller!.value.isPlaying;

    widget.onPositionUpdate(position);
    widget.onDurationUpdate(duration);
    widget.onPlayingStateUpdate(isPlaying);
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    controller.removeListener(_onVideoUpdate);
    try {
      await controller.pause();
    } catch (_) {
      // Ignored: pausing may fail if controller is not ready.
    }

    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Video controller dispose error: $e');
    }

    _controller = null;
    if (mounted) {
      setState(() {});
    }
  }

  void _reloadForNewMedia() {
    unawaited(_disposeController().then((_) => _initializePlayer()));
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  Future<void> seekTo(Duration position) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      await _controller!.seekTo(position);
    } catch (e) {
      debugPrint('Video seek error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
