import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../media_library/domain/entities/media_entity.dart';

/// Video player dedicated to the slideshow experience.
///
/// It keeps the [`SlideshowViewModel`] informed about playback progress and
/// notifies when the current video has finished so the carousel can advance to
/// the following media item.
class SlideshowVideoPlayer extends StatefulWidget {
  const SlideshowVideoPlayer({
    super.key,
    required this.media,
    required this.isPlaying,
    required this.isMuted,
    required this.isVideoLooping,
    required this.playbackSpeed,
    required this.onProgress,
    required this.onCompleted,
  });

  final MediaEntity media;
  final bool isPlaying;
  final bool isMuted;
  final bool isVideoLooping;
  final double playbackSpeed;
  final ValueChanged<double> onProgress;
  final VoidCallback onCompleted;

  @override
  State<SlideshowVideoPlayer> createState() => _SlideshowVideoPlayerState();
}

class _SlideshowVideoPlayerState extends State<SlideshowVideoPlayer> {
  VideoPlayerController? _controller;
  bool _hasCompleted = false;

  VideoPlayerController? get _activeController => _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(SlideshowVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.media.path != oldWidget.media.path) {
      _initializeController();
      return;
    }

    final controller = _activeController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (widget.isMuted != oldWidget.isMuted) {
      controller.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
    if (widget.isVideoLooping != oldWidget.isVideoLooping) {
      _hasCompleted = false;
      controller.setLooping(widget.isVideoLooping);
    }
    if (widget.playbackSpeed != oldWidget.playbackSpeed) {
      controller.setPlaybackSpeed(widget.playbackSpeed);
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      _hasCompleted = false;
      if (widget.isPlaying) {
        controller.play();
      } else {
        controller.pause();
      }
    }
  }

  Future<void> _initializeController() async {
    final previousController = _activeController;
    previousController?.removeListener(_onVideoUpdate);
    await previousController?.dispose();

    _hasCompleted = false;
    final controller = VideoPlayerController.file(File(widget.media.path));
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      await controller.setLooping(widget.isVideoLooping);
      await controller.setPlaybackSpeed(widget.playbackSpeed);
      controller.addListener(_onVideoUpdate);

      if (widget.isPlaying) {
        await controller.play();
      }

      widget.onProgress(0.0);

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Failed to initialize slideshow video: $error');
    }
  }

  void _onVideoUpdate() {
    final controller = _activeController;
    if (controller == null || !mounted) return;

    final value = controller.value;
    final duration = value.duration;
    final position = value.position;

    if (duration > Duration.zero) {
      final progress =
          (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      widget.onProgress(progress.toDouble());
    }

    final hasFinished = duration > Duration.zero && position >= duration;
    if (!widget.isVideoLooping && widget.isPlaying && hasFinished && !_hasCompleted) {
      _hasCompleted = true;
      widget.onProgress(1.0);
      widget.onCompleted();
    } else if (!hasFinished) {
      _hasCompleted = false;
    }
  }

  @override
  void dispose() {
    _activeController?.removeListener(_onVideoUpdate);
    _activeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _activeController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
