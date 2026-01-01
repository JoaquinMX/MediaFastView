import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/logging_service.dart';
import '../../../media_library/domain/entities/media_entity.dart';

/// Full-screen video player widget
class FullScreenVideoPlayer extends StatefulWidget {
  const FullScreenVideoPlayer({
    super.key,
    required this.media,
    required this.isPlaying,
    required this.isMuted,
    required this.isLooping,
    required this.playbackSpeed,
    required this.onPositionUpdate,
    required this.onDurationUpdate,
    required this.onPlayingStateUpdate,
  });

  final MediaEntity media;
  final bool isPlaying;
  final bool isMuted;
  final bool isLooping;
  final double playbackSpeed;
  final ValueChanged<Duration> onPositionUpdate;
  final ValueChanged<Duration> onDurationUpdate;
  final ValueChanged<bool> onPlayingStateUpdate;

  @override
  State<FullScreenVideoPlayer> createState() => FullScreenVideoPlayerState();
}

class FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    unawaited(_initializePlayer(widget.media));
  }

  @override
  void didUpdateWidget(FullScreenVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.media.id != oldWidget.media.id ||
        widget.media.path != oldWidget.media.path) {
      unawaited(
        _initializePlayer(widget.media, recreateController: true),
      );
      return;
    }

    // Update controller settings when widget properties change
    if (_controller != null) {
      if (widget.isMuted != oldWidget.isMuted) {
        _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      }
      if (widget.isLooping != oldWidget.isLooping) {
        _controller!.setLooping(widget.isLooping);
      }
      if (widget.playbackSpeed != oldWidget.playbackSpeed) {
        _controller!.setPlaybackSpeed(widget.playbackSpeed);
      }
      if (widget.isPlaying != oldWidget.isPlaying) {
        if (widget.isPlaying) {
          _controller!.play();
        } else {
          _controller!.pause();
        }
      }
    }
  }

  Future<void> _initializePlayer(MediaEntity media,
      {bool recreateController = false}) async {
    if (_initialization != null) {
      await _initialization;
    }

    final future = _performInitialization(media,
        recreateController: recreateController);
    _initialization = future;
    try {
      await future;
    } finally {
      if (identical(_initialization, future)) {
        _initialization = null;
      }
    }
  }

  Future<void> _performInitialization(MediaEntity media,
      {bool recreateController = false}) async {
    if (recreateController || _controller == null) {
      await _disposeController();

      final controller = VideoPlayerController.file(File(media.path));

      try {
        await controller.initialize();
        controller.setVolume(widget.isMuted ? 0.0 : 1.0);
        controller.setLooping(widget.isLooping);
        await controller.setPlaybackSpeed(widget.playbackSpeed);
        controller.addListener(_onVideoUpdate);

        if (widget.isPlaying) {
          await controller.play();
        }

        if (!mounted) {
          await controller.dispose();
          return;
        }

        widget.onDurationUpdate(controller.value.duration);
        widget.onPositionUpdate(controller.value.position);
        widget.onPlayingStateUpdate(controller.value.isPlaying);

        setState(() {
          _controller = controller;
        });
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to initialize video controller for ${media.path}: $error',
        );
        LoggingService.instance.debug(
          'Video initialization stack trace: $stackTrace',
        );
        await controller.dispose();
      }
      return;
    }

    // Controller already exists; ensure state matches widget configuration.
    if (widget.isMuted) {
      _controller!.setVolume(0.0);
    } else {
      _controller!.setVolume(1.0);
    }
    _controller!.setLooping(widget.isLooping);
    unawaited(_controller!.setPlaybackSpeed(widget.playbackSpeed));
    if (widget.isPlaying) {
      _controller!.play();
    } else {
      _controller!.pause();
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
      LoggingService.instance.error('Video seek error: $e');
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

  Future<void> _disposeController() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    controller.removeListener(_onVideoUpdate);
    _controller = null;

    if (mounted) {
      setState(() {});
    }

    try {
      await controller.dispose();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to dispose video controller for ${widget.media.path}: $error',
      );
      LoggingService.instance.debug(
        'Video dispose stack trace: $stackTrace',
      );
    }
  }
}
