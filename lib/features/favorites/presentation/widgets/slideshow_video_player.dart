import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/logging_service.dart';
import '../../../../shared/utils/playback_speed_applier.dart';
import '../../../../shared/utils/playback_speed_policy.dart';
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
    required this.seekNotifier,
    this.onPositionUpdate,
    this.onDurationUpdate,
    this.onPlaybackSpeedRejected,
  });

  final MediaEntity media;
  final bool isPlaying;
  final bool isMuted;
  final bool isVideoLooping;
  final double playbackSpeed;
  final ValueChanged<double> onProgress;
  final VoidCallback onCompleted;
  final ValueNotifier<Duration?> seekNotifier;
  final ValueChanged<Duration>? onPositionUpdate;
  final ValueChanged<Duration>? onDurationUpdate;
  final PlaybackSpeedRejectedCallback? onPlaybackSpeedRejected;

  @override
  State<SlideshowVideoPlayer> createState() => _SlideshowVideoPlayerState();
}

class _SlideshowVideoPlayerState extends State<SlideshowVideoPlayer> {
  VideoPlayerController? _controller;
  PlaybackSpeedApplier? _playbackSpeedApplier;
  bool _hasCompleted = false;

  VideoPlayerController? get _activeController => _controller;

  @override
  void initState() {
    super.initState();
    widget.seekNotifier.addListener(_onSeekRequested);
    unawaited(_initializeController());
  }

  @override
  void didUpdateWidget(SlideshowVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.media.path != oldWidget.media.path) {
      unawaited(_initializeController());
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
      _playbackSpeedApplier?.request(widget.playbackSpeed);
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
    _playbackSpeedApplier?.dispose();
    _playbackSpeedApplier = null;
    previousController?.removeListener(_onVideoUpdate);
    await previousController?.dispose();

    _hasCompleted = false;
    final controller = VideoPlayerController.file(File(widget.media.path));
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      await controller.setLooping(widget.isVideoLooping);
      final initialPlaybackSpeed = await _applyInitialPlaybackSpeed(controller);
      _playbackSpeedApplier = _createPlaybackSpeedApplier(
        controller,
        initialPlaybackSpeed.speed,
      );
      controller.addListener(_onVideoUpdate);

      if (widget.isPlaying) {
        await controller.play();
      }

      widget.onProgress(0.0);

      if (mounted) {
        setState(() {});
      }

      if (!initialPlaybackSpeed.wasRejected &&
          widget.playbackSpeed != initialPlaybackSpeed.speed) {
        _playbackSpeedApplier?.request(widget.playbackSpeed);
      }
    } catch (error) {
      LoggingService.instance.error(
        'Failed to initialize slideshow video for ${widget.media.path}: $error',
      );
    }
  }

  Future<({double speed, bool wasRejected})> _applyInitialPlaybackSpeed(
    VideoPlayerController controller,
  ) async {
    final requestedSpeed = widget.playbackSpeed;
    const fallbackSpeed = 1.0;

    try {
      await controller.setPlaybackSpeed(requestedSpeed);
      return (speed: requestedSpeed, wasRejected: false);
    } catch (error, stackTrace) {
      await _restoreInitialPlaybackSpeed(controller, fallbackSpeed);
      _reportPlaybackSpeedRejection(
        requestedSpeed,
        fallbackSpeed,
        error,
        stackTrace,
      );
      return (speed: fallbackSpeed, wasRejected: true);
    }
  }

  Future<void> _restoreInitialPlaybackSpeed(
    VideoPlayerController controller,
    double fallbackSpeed,
  ) async {
    try {
      await controller.setPlaybackSpeed(fallbackSpeed);
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to restore slideshow playback speed to '
        '${PlaybackSpeedPolicy.format(fallbackSpeed)}x: $error',
      );
      LoggingService.instance.debug(
        'Slideshow playback speed restore stack trace: $stackTrace',
      );
    }
  }

  PlaybackSpeedApplier _createPlaybackSpeedApplier(
    VideoPlayerController controller,
    double initialSpeed,
  ) {
    return PlaybackSpeedApplier(
      apply: controller.setPlaybackSpeed,
      initialSpeed: initialSpeed,
      onRejected: _reportPlaybackSpeedRejection,
    );
  }

  void _reportPlaybackSpeedRejection(
    double attemptedSpeed,
    double fallbackSpeed,
    Object error,
    StackTrace stackTrace,
  ) {
    LoggingService.instance.error(
      'Failed to set slideshow playback speed to '
      '${PlaybackSpeedPolicy.format(attemptedSpeed)}x: $error',
    );
    LoggingService.instance.debug(
      'Slideshow playback speed stack trace: $stackTrace',
    );
    if (mounted) {
      widget.onPlaybackSpeedRejected?.call(attemptedSpeed, fallbackSpeed);
    }
  }

  void _onVideoUpdate() {
    final controller = _activeController;
    if (controller == null || !mounted) return;

    final value = controller.value;
    final duration = value.duration;
    final position = value.position;

    widget.onPositionUpdate?.call(position);
    widget.onDurationUpdate?.call(duration);

    if (duration > Duration.zero) {
      final progress = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0);
      widget.onProgress(progress.toDouble());
    }

    final hasFinished = duration > Duration.zero && position >= duration;
    if (!widget.isVideoLooping &&
        widget.isPlaying &&
        hasFinished &&
        !_hasCompleted) {
      _hasCompleted = true;
      widget.onProgress(1.0);
      widget.onCompleted();
    } else if (!hasFinished) {
      _hasCompleted = false;
    }
  }

  void _onSeekRequested() {
    final position = widget.seekNotifier.value;
    if (position != null && _controller != null) {
      _controller!.seekTo(position);
      widget.seekNotifier.value = null; // Reset
    }
  }

  @override
  void dispose() {
    widget.seekNotifier.removeListener(_onSeekRequested);
    _playbackSpeedApplier?.dispose();
    _controller?.dispose();
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

    // Audio-only assets have no video surface, so render a music icon instead
    // while the controller drives playback and progress.
    if (widget.media.type == MediaType.audio) {
      return _buildAudioSurface(context);
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildAudioSurface(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note,
            size: 160,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.media.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
