import 'dart:async';
import 'dart:math';

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
    required this.isShuffleEnabled,
    required this.displayDuration,
  });

  final int currentIndex;
  final bool isPlaying;
  final bool isLooping;
  final bool isMuted;
  final double progress;
  final bool isShuffleEnabled;
  final Duration displayDuration;

  SlideshowPlaying copyWith({
    int? currentIndex,
    bool? isPlaying,
    bool? isLooping,
    bool? isMuted,
    double? progress,
    bool? isShuffleEnabled,
    Duration? displayDuration,
  }) {
    return SlideshowPlaying(
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isMuted: isMuted ?? this.isMuted,
      progress: progress ?? this.progress,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      displayDuration: displayDuration ?? this.displayDuration,
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
    required this.isShuffleEnabled,
    required this.displayDuration,
  });

  final int currentIndex;
  final bool isLooping;
  final bool isMuted;
  final double progress;
  final bool isShuffleEnabled;
  final Duration displayDuration;

  SlideshowPaused copyWith({
    int? currentIndex,
    bool? isLooping,
    bool? isMuted,
    double? progress,
    bool? isShuffleEnabled,
    Duration? displayDuration,
  }) {
    return SlideshowPaused(
      currentIndex: currentIndex ?? this.currentIndex,
      isLooping: isLooping ?? this.isLooping,
      isMuted: isMuted ?? this.isMuted,
      progress: progress ?? this.progress,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      displayDuration: displayDuration ?? this.displayDuration,
    );
  }
}

/// Slideshow finished state.
class SlideshowFinished extends SlideshowState {
  const SlideshowFinished();
}

/// ViewModel for managing slideshow state and operations.
class SlideshowViewModel extends StateNotifier<SlideshowState> {
  SlideshowViewModel(this._mediaList)
      : _imageDisplayDuration = const Duration(seconds: 5),
        _mediaOrder = List.generate(_mediaList.length, (index) => index),
        super(const SlideshowIdle()) {
    if (_mediaList.isNotEmpty) {
      _initializeSlideshow();
    }
  }

  final List<MediaEntity> _mediaList;
  Timer? _timer;
  static const Duration _progressInterval = Duration(milliseconds: 100);
  final Random _random = Random();
  Duration _imageDisplayDuration;
  List<int> _mediaOrder;
  bool _isShuffleEnabled = false;

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
  bool get isShuffleEnabled => _isShuffleEnabled;
  Duration get displayDuration => _imageDisplayDuration;

  MediaEntity? get currentMedia {
    if (_mediaList.isEmpty || currentIndex >= _mediaOrder.length) {
      return null;
    }
    final mediaIndex = _mediaOrder[currentIndex];
    if (mediaIndex < 0 || mediaIndex >= _mediaList.length) {
      return null;
    }
    return _mediaList[mediaIndex];
  }

  int get totalItems => _mediaList.length;

  void _initializeSlideshow() {
    state = SlideshowPaused(
      currentIndex: 0,
      isLooping: false,
      isMuted: false,
      progress: 0.0,
      isShuffleEnabled: _isShuffleEnabled,
      displayDuration: _imageDisplayDuration,
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
      isShuffleEnabled: _isShuffleEnabled,
      displayDuration: _imageDisplayDuration,
    );

    _startTimer();
  }

  /// Pauses the slideshow.
  void pauseSlideshow() {
    _timer?.cancel();
    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = SlideshowPaused(
        currentIndex: currentState.currentIndex,
        isLooping: currentState.isLooping,
        isMuted: currentState.isMuted,
        progress: currentState.progress,
        isShuffleEnabled: currentState.isShuffleEnabled,
        displayDuration: currentState.displayDuration,
      );
    }
  }

  /// Resumes the slideshow.
  void resumeSlideshow() {
    if (_mediaList.isEmpty) return;

    final currentState = state;
    if (currentState is SlideshowPaused) {
      state = SlideshowPlaying(
        currentIndex: currentState.currentIndex,
        isPlaying: true,
        isLooping: currentState.isLooping,
        isMuted: currentState.isMuted,
        progress: currentState.progress,
        isShuffleEnabled: currentState.isShuffleEnabled,
        displayDuration: currentState.displayDuration,
      );
    }

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

    final total = _mediaOrder.length;
    final nextIndex = total == 0 ? 0 : (currentIndex + 1) % total;
    if (total != 0 && nextIndex == 0 && !isLooping) {
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

    final total = _mediaOrder.length;
    if (total == 0) {
      return;
    }
    final prevIndex = currentIndex > 0
        ? currentIndex - 1
        : total - 1;
    _goToIndex(prevIndex);
  }

  /// Goes to a specific index in the slideshow.
  void goToIndex(int index) {
    if (index < 0 || index >= _mediaOrder.length) return;
    _goToIndex(index);
  }

  void _goToIndex(int index) {
    final wasPlaying = isPlaying;
    _timer?.cancel();

    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = currentState.copyWith(
        currentIndex: index,
        progress: 0.0,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        currentIndex: index,
        progress: 0.0,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    }

    if (wasPlaying) {
      _startTimer();
    }
  }

  /// Toggles loop mode.
  void toggleLoop() {
    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = currentState.copyWith(
        isLooping: !currentState.isLooping,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        isLooping: !currentState.isLooping,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    }
  }

  /// Toggles mute state.
  void toggleMute() {
    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = currentState.copyWith(
        isMuted: !currentState.isMuted,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        isMuted: !currentState.isMuted,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    }
  }

  /// Updates progress (for video playback).
  void updateProgress(double progress) {
    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = currentState.copyWith(
        progress: progress,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        progress: progress,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    }
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

    final increment = _imageDisplayDuration.inMilliseconds == 0
        ? 1.0
        : _progressInterval.inMilliseconds /
            _imageDisplayDuration.inMilliseconds;
    final updatedProgress = switch (state) {
      SlideshowPlaying(:final progress) => progress + increment,
      _ => 0.0,
    };
    final clampedProgress = updatedProgress.clamp(0.0, 1.0).toDouble();

    if (clampedProgress >= 1.0) {
      nextItem();
    } else {
      updateProgress(clampedProgress);
    }
  }

  /// Toggles shuffle mode for the slideshow.
  void toggleShuffle() {
    if (_mediaList.isEmpty) {
      return;
    }

    final currentMedia = this.currentMedia;
    _isShuffleEnabled = !_isShuffleEnabled;

    if (_isShuffleEnabled) {
      _mediaOrder = List<int>.from(_mediaOrder);
      _mediaOrder.shuffle(_random);
    } else {
      _mediaOrder = List<int>.generate(_mediaList.length, (index) => index);
    }

    var newIndex = 0;
    if (currentMedia != null) {
      final mediaIndex = _mediaList.indexOf(currentMedia);
      final orderIndex = _mediaOrder.indexOf(mediaIndex);
      if (orderIndex != -1) {
        newIndex = orderIndex;
      }
    }

    final currentState = state;
    if (currentState is SlideshowPlaying) {
      state = currentState.copyWith(
        currentIndex: newIndex,
        progress: 0.0,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
      _startTimer();
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        currentIndex: newIndex,
        progress: 0.0,
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else {
      _initializeSlideshow();
    }
  }

  /// Updates the display duration for images in the slideshow.
  void updateDisplayDuration(Duration newDuration) {
    if (newDuration <= Duration.zero) {
      return;
    }

    final oldDuration = _imageDisplayDuration;
    _imageDisplayDuration = newDuration;
    final currentState = state;

    double _adjustProgress(double progress) {
      if (oldDuration.inMilliseconds == 0) {
        return 0.0;
      }
      final scaled =
          progress * oldDuration.inMilliseconds / newDuration.inMilliseconds;
      return scaled.clamp(0.0, 1.0);
    }

    if (currentState is SlideshowPlaying) {
      final updatedState = currentState.copyWith(
        progress: _adjustProgress(currentState.progress),
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
      state = updatedState;
      if (updatedState.isPlaying) {
        _startTimer();
      }
    } else if (currentState is SlideshowPaused) {
      state = currentState.copyWith(
        progress: _adjustProgress(currentState.progress),
        isShuffleEnabled: _isShuffleEnabled,
        displayDuration: _imageDisplayDuration,
      );
    } else if (currentState is SlideshowIdle) {
      _initializeSlideshow();
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
