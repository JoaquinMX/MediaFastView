import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';

/// Sealed class representing the state of slideshow.
sealed class SlideshowState {
  const SlideshowState();
}

/// Slideshow idle state.
class SlideshowIdle extends SlideshowState {
  const SlideshowIdle();
}

/// Slideshow playing state.
class SlideshowPlaying extends SlideshowState {
  const SlideshowPlaying({
    required this.currentIndex,
    required this.isPlaying,
    required this.isLooping,
    required this.isMuted,
    required this.progress,
  });

  final int currentIndex;
  final bool isPlaying;
  final bool isLooping;
  final bool isMuted;
  final double progress;

  SlideshowPlaying copyWith({
    int? currentIndex,
    bool? isPlaying,
    bool? isLooping,
    bool? isMuted,
    double? progress,
  }) {
    return SlideshowPlaying(
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isMuted: isMuted ?? this.isMuted,
      progress: progress ?? this.progress,
    );
  }
}

/// Slideshow paused state.
class SlideshowPaused extends SlideshowState {
  const SlideshowPaused({
    required this.currentIndex,
    required this.isLooping,
    required this.isMuted,
    required this.progress,
  });

  final int currentIndex;
  final bool isLooping;
  final bool isMuted;
  final double progress;
}

/// Slideshow finished state.
class SlideshowFinished extends SlideshowState {
  const SlideshowFinished();
}

/// ViewModel for managing slideshow state and operations.
class SlideshowViewModel extends StateNotifier<SlideshowState> {
  SlideshowViewModel(this._mediaList) : super(const SlideshowIdle()) {
    if (_mediaList.isNotEmpty) {
      _initializeSlideshow();
    }
  }

  final List<MediaEntity> _mediaList;
  Timer? _timer;
  static const Duration _imageDisplayDuration = Duration(seconds: 5);
  static const Duration _progressInterval = Duration(milliseconds: 100);
  static final double _imageProgressIncrement =
      _progressInterval.inMilliseconds / _imageDisplayDuration.inMilliseconds;

  int get currentIndex => switch (state) {
    SlideshowPlaying(:final currentIndex) => currentIndex,
    SlideshowPaused(:final currentIndex) => currentIndex,
    _ => 0,
  };

  bool get isPlaying =>
      state is SlideshowPlaying && (state as SlideshowPlaying).isPlaying;
  bool get isLooping => switch (state) {
    SlideshowPlaying(:final isLooping) => isLooping,
    SlideshowPaused(:final isLooping) => isLooping,
    _ => false,
  };
  bool get isMuted => switch (state) {
    SlideshowPlaying(:final isMuted) => isMuted,
    SlideshowPaused(:final isMuted) => isMuted,
    _ => false,
  };

  MediaEntity? get currentMedia =>
      _mediaList.isNotEmpty && currentIndex < _mediaList.length
      ? _mediaList[currentIndex]
      : null;

  int get totalItems => _mediaList.length;

  void _initializeSlideshow() {
    state = SlideshowPaused(
      currentIndex: 0,
      isLooping: false,
      isMuted: false,
      progress: 0.0,
    );
  }

  /// Starts the slideshow.
  void startSlideshow() {
    if (_mediaList.isEmpty) return;

    state = SlideshowPlaying(
      currentIndex: currentIndex,
      isPlaying: true,
      isLooping: isLooping,
      isMuted: isMuted,
      progress: 0.0,
    );

    _startTimer();
  }

  /// Pauses the slideshow.
  void pauseSlideshow() {
    _timer?.cancel();
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      _ => state,
    };
  }

  /// Resumes the slideshow.
  void resumeSlideshow() {
    if (_mediaList.isEmpty) return;

    state = switch (state) {
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: true,
          isLooping: isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      _ => state,
    };

    _startTimer();
  }

  /// Stops the slideshow.
  void stopSlideshow() {
    _timer?.cancel();
    state = const SlideshowIdle();
  }

  /// Goes to the next item in the slideshow.
  void nextItem() {
    if (_mediaList.isEmpty) return;

    final nextIndex = (currentIndex + 1) % _mediaList.length;
    if (nextIndex == 0 && !isLooping) {
      // End of slideshow
      _timer?.cancel();
      state = const SlideshowFinished();
      return;
    }

    _goToIndex(nextIndex);
  }

  /// Goes to the previous item in the slideshow.
  void previousItem() {
    if (_mediaList.isEmpty) return;

    final prevIndex = currentIndex > 0
        ? currentIndex - 1
        : _mediaList.length - 1;
    _goToIndex(prevIndex);
  }

  /// Goes to a specific index in the slideshow.
  void goToIndex(int index) {
    if (index < 0 || index >= _mediaList.length) return;
    _goToIndex(index);
  }

  void _goToIndex(int index) {
    final wasPlaying = isPlaying;
    _timer?.cancel();

    state = switch (state) {
      SlideshowPlaying(:final isLooping, :final isMuted) => SlideshowPlaying(
        currentIndex: index,
        isPlaying: wasPlaying,
        isLooping: isLooping,
        isMuted: isMuted,
        progress: 0.0,
      ),
      SlideshowPaused(:final isLooping, :final isMuted) => SlideshowPaused(
        currentIndex: index,
        isLooping: isLooping,
        isMuted: isMuted,
        progress: 0.0,
      ),
      _ => state,
    };

    if (wasPlaying) {
      _startTimer();
    }
  }

  /// Toggles loop mode.
  void toggleLoop() {
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: !isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: !isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      _ => state,
    };
  }

  /// Toggles mute state.
  void toggleMute() {
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isMuted: !isMuted,
          progress: progress,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isMuted: !isMuted,
          progress: progress,
        ),
      _ => state,
    };
  }

  /// Updates progress (for video playback).
  void updateProgress(double progress) {
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isMuted,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      SlideshowPaused(:final currentIndex, :final isLooping, :final isMuted) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isMuted: isMuted,
          progress: progress,
        ),
      _ => state,
    };
  }

  void _startTimer() {
    _timer?.cancel();

    // Only start timer for images, videos handle their own timing
    final currentMedia = this.currentMedia;
    if (currentMedia != null && currentMedia.type != MediaType.video) {
      _timer = Timer.periodic(_progressInterval, _updateProgress);
    }
  }

  void _updateProgress(Timer timer) {
    final currentMedia = this.currentMedia;
    if (currentMedia == null || currentMedia.type == MediaType.video) return;

    final updatedProgress = switch (state) {
      SlideshowPlaying(:final progress) => progress + _imageProgressIncrement,
      _ => 0.0,
    };
    final clampedProgress = updatedProgress.clamp(0.0, 1.0).toDouble();

    if (clampedProgress >= 1.0) {
      nextItem();
    } else {
      updateProgress(clampedProgress);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Provider for SlideshowViewModel with auto-dispose.
final slideshowViewModelProvider = StateNotifierProvider.autoDispose
    .family<SlideshowViewModel, SlideshowState, List<MediaEntity>>(
      (ref, mediaList) => SlideshowViewModel(mediaList),
    );
