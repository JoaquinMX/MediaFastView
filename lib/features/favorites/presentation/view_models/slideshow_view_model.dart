import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../../shared/utils/tag_mutation_service.dart';
import '../../../tagging/domain/entities/tag_entity.dart';

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
    required this.isVideoLooping,
    required this.isMuted,
    required this.progress,
    required this.isShuffleEnabled,
    required this.imageDisplayDuration,
  });

  final int currentIndex;
  final bool isPlaying;
  final bool isLooping;
  final bool isVideoLooping;
  final bool isMuted;
  final double progress;
  final bool isShuffleEnabled;
  final Duration imageDisplayDuration;

  SlideshowPlaying copyWith({
    int? currentIndex,
    bool? isPlaying,
    bool? isLooping,
    bool? isVideoLooping,
    bool? isMuted,
    double? progress,
    bool? isShuffleEnabled,
    Duration? imageDisplayDuration,
  }) {
    return SlideshowPlaying(
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isVideoLooping: isVideoLooping ?? this.isVideoLooping,
      isMuted: isMuted ?? this.isMuted,
      progress: progress ?? this.progress,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      imageDisplayDuration:
          imageDisplayDuration ?? this.imageDisplayDuration,
    );
  }
}

/// Slideshow paused state.
class SlideshowPaused extends SlideshowState {
  const SlideshowPaused({
    required this.currentIndex,
    required this.isLooping,
    required this.isVideoLooping,
    required this.isMuted,
    required this.progress,
    required this.isShuffleEnabled,
    required this.imageDisplayDuration,
  });

  final int currentIndex;
  final bool isLooping;
  final bool isVideoLooping;
  final bool isMuted;
  final double progress;
  final bool isShuffleEnabled;
  final Duration imageDisplayDuration;
}

/// Slideshow finished state.
class SlideshowFinished extends SlideshowState {
  const SlideshowFinished();
}

/// ViewModel for managing slideshow state and operations.
class SlideshowViewModel extends StateNotifier<SlideshowState> {
  SlideshowViewModel(
    this._mediaList, {
    required TagMutationService tagMutationService,
  })  : _tagMutationService = tagMutationService,
        super(const SlideshowIdle()) {
    if (_mediaList.isNotEmpty) {
      _initializeSlideshow();
    }
  }

  final List<MediaEntity> _mediaList;
  final TagMutationService _tagMutationService;
  Timer? _timer;
  final Random _random = Random();
  bool _isShuffleEnabled = false;
  Duration _imageDisplayDuration = const Duration(seconds: 5);
  List<int> _playOrder = [];
  static const Duration _progressInterval = Duration(milliseconds: 100);

  double get _imageProgressIncrement {
    final durationMs = _imageDisplayDuration.inMilliseconds;
    if (durationMs <= 0) {
      return 1.0;
    }
    return _progressInterval.inMilliseconds / durationMs;
  }

  int get currentIndex {
    final index = switch (state) {
      SlideshowPlaying(:final currentIndex) => currentIndex,
      SlideshowPaused(:final currentIndex) => currentIndex,
      _ => 0,
    };

    if (_playOrder.isEmpty) {
      return index;
    }

    if (index < 0) {
      return 0;
    }

    if (index >= _playOrder.length) {
      return _playOrder.length - 1;
    }

    return index;
  }

  Future<TagMutationResult> toggleTag(TagEntity tag) async {
    final media = currentMedia;
    if (media == null) {
      return const TagMutationResult(outcome: TagMutationOutcome.unchanged);
    }

    final result = await _tagMutationService.toggleTagForMedia(media, tag);
    final mediaIndex =
        _playOrder.isNotEmpty ? _playOrder[currentIndex] : currentIndex;

    if (result.updatedMedia != null &&
        mediaIndex >= 0 &&
        mediaIndex < _mediaList.length) {
      _mediaList[mediaIndex] = result.updatedMedia!;
      _emitStateUpdate();
    }

    return result;
  }

  bool get isPlaying =>
      state is SlideshowPlaying && (state as SlideshowPlaying).isPlaying;
  bool get isLooping => switch (state) {
    SlideshowPlaying(:final isLooping) => isLooping,
    SlideshowPaused(:final isLooping) => isLooping,
    _ => false,
  };
  bool get isVideoLooping => switch (state) {
    SlideshowPlaying(:final isVideoLooping) => isVideoLooping,
    SlideshowPaused(:final isVideoLooping) => isVideoLooping,
    _ => false,
  };
  bool get isMuted => switch (state) {
    SlideshowPlaying(:final isMuted) => isMuted,
    SlideshowPaused(:final isMuted) => isMuted,
    _ => false,
  };

  MediaEntity? get currentMedia {
    if (_mediaList.isEmpty || _playOrder.isEmpty) {
      return null;
    }
    final orderIndex = currentIndex;
    if (orderIndex < 0 || orderIndex >= _playOrder.length) {
      return null;
    }
    final mediaIndex = _playOrder[orderIndex];
    if (mediaIndex < 0 || mediaIndex >= _mediaList.length) {
      return null;
    }
    return _mediaList[mediaIndex];
  }

  int get totalItems => _playOrder.isNotEmpty ? _playOrder.length : _mediaList.length;

  void _emitStateUpdate() {
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      _ => state,
    };
  }

  void _initializeSlideshow() {
    _rebuildPlayOrder();
    state = SlideshowPaused(
      currentIndex: 0,
      isLooping: false,
      isVideoLooping: false,
      isMuted: false,
      progress: 0.0,
      isShuffleEnabled: _isShuffleEnabled,
      imageDisplayDuration: _imageDisplayDuration,
    );
  }

  /// Starts the slideshow.
  void startSlideshow() {
    if (_mediaList.isEmpty) return;
    if (_playOrder.isEmpty) {
      _rebuildPlayOrder();
    }
    if (_playOrder.isEmpty) return;

    state = SlideshowPlaying(
      currentIndex: currentIndex,
      isPlaying: true,
      isLooping: isLooping,
      isVideoLooping: isVideoLooping,
      isMuted: isMuted,
      progress: 0.0,
      isShuffleEnabled: _isShuffleEnabled,
      imageDisplayDuration: _imageDisplayDuration,
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
        :final isVideoLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
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
        :final isVideoLooping,
        :final isMuted,
        :final progress,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: true,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
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
    if (_mediaList.isEmpty || _playOrder.isEmpty) return;

    final nextIndex = (currentIndex + 1) % _playOrder.length;
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
    if (_mediaList.isEmpty || _playOrder.isEmpty) return;

    final prevIndex = currentIndex > 0
        ? currentIndex - 1
        : _playOrder.length - 1;
    _goToIndex(prevIndex);
  }

  /// Goes to a specific index in the slideshow.
  void goToIndex(int index) {
    if (index < 0 || index >= _playOrder.length) return;
    _goToIndex(index);
  }

  void _goToIndex(int index) {
    final wasPlaying = isPlaying;
    _timer?.cancel();

    state = switch (state) {
      SlideshowPlaying(:final isLooping, :final isVideoLooping, :final isMuted) =>
        SlideshowPlaying(
          currentIndex: index,
          isPlaying: wasPlaying,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: 0.0,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
        ),
      SlideshowPaused(:final isLooping, :final isVideoLooping, :final isMuted) =>
        SlideshowPaused(
          currentIndex: index,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: 0.0,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
        ),
      _ => wasPlaying
          ? SlideshowPlaying(
              currentIndex: index,
              isPlaying: wasPlaying,
              isLooping: false,
              isVideoLooping: isVideoLooping,
              isMuted: false,
              progress: 0.0,
              isShuffleEnabled: _isShuffleEnabled,
              imageDisplayDuration: _imageDisplayDuration,
            )
          : SlideshowPaused(
              currentIndex: index,
              isLooping: false,
              isVideoLooping: isVideoLooping,
              isMuted: false,
              progress: 0.0,
              isShuffleEnabled: _isShuffleEnabled,
              imageDisplayDuration: _imageDisplayDuration,
            ),
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
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: !isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: !isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      _ => state,
    };
  }

  /// Toggles looping for the current video item without advancing the slideshow.
  void toggleVideoLoop() {
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isVideoLooping: !isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: !isVideoLooping,
          isMuted: isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
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
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: !isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final progress,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: !isMuted,
          progress: progress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      _ => state,
    };
  }

  /// Toggles shuffle mode and rebuilds the play order.
  void toggleShuffle() {
    if (_mediaList.isEmpty) return;

    final previousMediaIndex =
        _playOrder.isNotEmpty && currentIndex < _playOrder.length
            ? _playOrder[currentIndex]
            : null;

    _isShuffleEnabled = !_isShuffleEnabled;
    _rebuildPlayOrder();

    if (_playOrder.isEmpty) {
      return;
    }

    final newIndex = previousMediaIndex != null
        ? _playOrder.indexOf(previousMediaIndex)
        : 0;

    _goToIndex(newIndex >= 0 ? newIndex : 0);
  }

  /// Updates the image display duration and restarts the timer if needed.
  void setImageDisplayDuration(Duration duration) {
    if (duration.inMilliseconds <= 0) return;

    _imageDisplayDuration = duration;
    final wasPlaying = isPlaying;
    _timer?.cancel();

    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: true,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: 0.0,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: 0.0,
          isShuffleEnabled: _isShuffleEnabled,
          imageDisplayDuration: _imageDisplayDuration,
        ),
      SlideshowIdle() =>
        _playOrder.isEmpty
            ? const SlideshowIdle()
            : SlideshowPaused(
                currentIndex: 0,
                isLooping: false,
                isVideoLooping: false,
                isMuted: false,
                progress: 0.0,
                isShuffleEnabled: _isShuffleEnabled,
                imageDisplayDuration: _imageDisplayDuration,
              ),
      _ => state,
    };

    if (wasPlaying) {
      _startTimer();
    }
  }

  /// Updates progress (for video playback).
  void updateProgress(double progress) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    state = switch (state) {
      SlideshowPlaying(
        :final currentIndex,
        :final isPlaying,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPlaying(
          currentIndex: currentIndex,
          isPlaying: isPlaying,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: clampedProgress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      SlideshowPaused(
        :final currentIndex,
        :final isLooping,
        :final isVideoLooping,
        :final isMuted,
        :final isShuffleEnabled,
        :final imageDisplayDuration,
      ) =>
        SlideshowPaused(
          currentIndex: currentIndex,
          isLooping: isLooping,
          isVideoLooping: isVideoLooping,
          isMuted: isMuted,
          progress: clampedProgress,
          isShuffleEnabled: isShuffleEnabled,
          imageDisplayDuration: imageDisplayDuration,
        ),
      _ => state,
    };
  }

  void _rebuildPlayOrder() {
    _playOrder = List.generate(_mediaList.length, (index) => index);
    if (_isShuffleEnabled) {
      _playOrder.shuffle(_random);
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
      (ref, mediaList) => SlideshowViewModel(
        mediaList,
        tagMutationService: ref.watch(tagMutationServiceProvider),
      ),
    );
