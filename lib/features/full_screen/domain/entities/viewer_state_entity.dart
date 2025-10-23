import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';

/// Sealed class representing the state of the full-screen media viewer
sealed class FullScreenState {
  const FullScreenState();
}

/// Initial state before loading any media
class FullScreenInitial extends FullScreenState {
  const FullScreenInitial();
}

/// Loading state while fetching media data
class FullScreenLoading extends FullScreenState {
  const FullScreenLoading();
}

/// Loaded state with media data and current viewing position
class FullScreenLoaded extends FullScreenState {
  const FullScreenLoaded({
    required this.mediaList,
    required this.currentIndex,
    required this.isPlaying,
    required this.isMuted,
    required this.isLooping,
    required this.currentPosition,
    required this.totalDuration,
    required this.isFavorite,
    required this.currentMediaTags,
    required this.shortcutTags,
  });

  final List<MediaEntity> mediaList;
  final int currentIndex;
  final bool isPlaying;
  final bool isMuted;
  final bool isLooping;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isFavorite;
  final List<TagEntity> currentMediaTags;
  final List<TagEntity> shortcutTags;

  MediaEntity get currentMedia => mediaList[currentIndex];

  FullScreenLoaded copyWith({
    List<MediaEntity>? mediaList,
    int? currentIndex,
    bool? isPlaying,
    bool? isMuted,
    bool? isLooping,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isFavorite,
    List<TagEntity>? currentMediaTags,
    List<TagEntity>? shortcutTags,
  }) {
    return FullScreenLoaded(
      mediaList: mediaList ?? this.mediaList,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isLooping: isLooping ?? this.isLooping,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isFavorite: isFavorite ?? this.isFavorite,
      currentMediaTags: currentMediaTags ?? this.currentMediaTags,
      shortcutTags: shortcutTags ?? this.shortcutTags,
    );
  }
}

/// Error state when loading fails
class FullScreenError extends FullScreenState {
  const FullScreenError(this.message);

  final String message;
}

/// Permission revoked state when directory access is denied
class FullScreenPermissionRevoked extends FullScreenState {
  const FullScreenPermissionRevoked();
}
