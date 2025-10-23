import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../../tagging/presentation/view_models/tag_management_view_model.dart';
import '../../../tagging/presentation/view_models/tags_view_model.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/video_playback_settings_provider.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../../../shared/utils/tag_lookup.dart';
import '../../../../shared/utils/tag_usage_ranker.dart';
import '../../domain/use_cases/load_media_for_viewing_use_case.dart';
import '../../domain/entities/viewer_state_entity.dart';
import '../../../../core/services/logging_service.dart';

/// ViewModel for full-screen media viewing
class FullScreenViewModel extends StateNotifier<FullScreenState> {
  FullScreenViewModel(
    this._loadMediaUseCase,
    this._favoritesViewModel,
    this._favoritesRepository,
    this._assignTagUseCase,
    this._tagLookup,
    this._tagCacheRefresher,
    VideoPlaybackSettings playbackSettings, {
    TagUsageRanker? tagUsageRanker,
  })  : _playbackSettings = playbackSettings,
        _tagUsageRanker = tagUsageRanker ?? const TagUsageRanker(),
        super(const FullScreenInitial());

  final LoadMediaForViewingUseCase _loadMediaUseCase;
  final FavoritesViewModel _favoritesViewModel;
  final FavoritesRepository _favoritesRepository;
  final AssignTagUseCase _assignTagUseCase;
  final TagLookup _tagLookup;
  final TagCacheRefresher _tagCacheRefresher;
  final TagUsageRanker _tagUsageRanker;

  VideoPlayerController? _videoController;
  VideoPlaybackSettings _playbackSettings;
  bool _loopOverridden = false;

  /// Initialize the viewer with media from a directory or provided media list
  Future<void> initialize(String directoryPath, {String? initialMediaId, String? bookmarkData, List<MediaEntity>? mediaList}) async {
    LoggingService.instance.info('Initializing with directoryPath: $directoryPath, initialMediaId: $initialMediaId, mediaList provided: ${mediaList != null}');
    Future(() {
      state = const FullScreenLoading();
    });

    try {
      final List<MediaEntity> finalMediaList;

      if (mediaList != null) {
        // Use provided media list (e.g., favorites)
        finalMediaList = mediaList;
        LoggingService.instance.info('Using provided mediaList with ${finalMediaList.length} items');
      } else {
        // Load media from directory
        // Generate directoryId from path for consistency
        final directoryId = generateDirectoryId(directoryPath);
        LoggingService.instance.debug('Generated directoryId: $directoryId');

        LoggingService.instance.debug('Calling _loadMediaUseCase.call($directoryPath, $directoryId, bookmarkData: $bookmarkData)');
        finalMediaList = await _loadMediaUseCase.call(directoryPath, directoryId, bookmarkData: bookmarkData);
        LoggingService.instance.info('Received mediaList with ${finalMediaList.length} items');
      }

      if (finalMediaList.isEmpty) {
        LoggingService.instance.warning('mediaList is empty, setting error state');
        Future(() {
          state = const FullScreenError('No media found');
        });
        return;
      }

      final currentIndex = initialMediaId != null
          ? finalMediaList.indexWhere((media) => media.id == initialMediaId)
          : 0;

      if (currentIndex == -1) {
        Future(() {
          state = const FullScreenError('Initial media not found');
        });
        return;
      }

      final currentMedia = finalMediaList[currentIndex];
      final isVideo = currentMedia.type == MediaType.video;

      // Check if current media is favorite
      final isFavorite = await _favoritesRepository.isFavorite(
        currentMedia.id,
      );

      _loopOverridden = false;

      final currentTags = await _tagLookup.getTagsByIds(currentMedia.tagIds);
      final shortcutTags = await _buildShortcutTags(finalMediaList);

      Future(() {
        state = FullScreenLoaded(
          mediaList: finalMediaList,
          currentIndex: currentIndex,
          isPlaying: isVideo && _playbackSettings.autoplayVideos,
          isMuted: false,
          isLooping: isVideo && _playbackSettings.loopVideos,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isFavorite: isFavorite,
          currentMediaTags: currentTags,
          shortcutTags: shortcutTags,
        );
      });

      // Initialize video controller if current media is video
      if (isVideo) {
        await _initializeVideoController(currentMedia);
      } else {
        await _disposeVideoController();
      }
    } catch (e) {
      LoggingService.instance.error('Error during initialization: $e');
      // Check if this is a permission-related error
      final errorMessage = e.toString();
      if (_isPermissionError(errorMessage)) {
        LoggingService.instance.warning('Permission error detected');
        Future(() {
          state = const FullScreenPermissionRevoked();
        });
      } else {
        Future(() {
          state = FullScreenError(errorMessage);
        });
      }
    }
  }

  /// Attempt to recover permissions for the current directory
  Future<bool> attemptPermissionRecovery(String directoryPath, {String? bookmarkData}) async {
    final permissionService = PermissionService();
    permissionService.logPermissionEvent(
      'fullscreen_recovery_attempt',
      path: directoryPath,
      details: 'bookmark_present=${bookmarkData != null}',
    );

    try {
      // Try to re-initialize with the same parameters
      await initialize(directoryPath, bookmarkData: bookmarkData);
      permissionService.logPermissionEvent(
        'fullscreen_recovery_success',
        path: directoryPath,
      );
      return true;
    } catch (e) {
      permissionService.logPermissionEvent(
        'fullscreen_recovery_failed',
        path: directoryPath,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Navigate to next media
  Future<void> nextMedia() async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentIndex < currentState.mediaList.length - 1) {
      final newIndex = currentState.currentIndex + 1;
      final nextMedia = currentState.mediaList[newIndex];
      final isFavorite = await _favoritesRepository.isFavorite(nextMedia.id);
      final nextTags = await _tagLookup.getTagsByIds(nextMedia.tagIds);

      state = currentState.copyWith(
        currentIndex: newIndex,
        isFavorite: isFavorite,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlaying:
            nextMedia.type == MediaType.video && _playbackSettings.autoplayVideos,
        isLooping:
            nextMedia.type == MediaType.video && _playbackSettings.loopVideos,
        currentMediaTags: nextTags,
      );

      _loopOverridden = false;

      // Initialize new media if video
      if (nextMedia.type == MediaType.video) {
        await _initializeVideoController(nextMedia);
      } else {
        await _disposeVideoController();
      }
    }
  }

  /// Navigate to previous media
  Future<void> previousMedia() async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentIndex > 0) {
      final newIndex = currentState.currentIndex - 1;
      final previousMedia = currentState.mediaList[newIndex];
      final isFavorite = await _favoritesRepository.isFavorite(
        previousMedia.id,
      );
      final previousTags = await _tagLookup.getTagsByIds(previousMedia.tagIds);

      state = currentState.copyWith(
        currentIndex: newIndex,
        isFavorite: isFavorite,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlaying: previousMedia.type == MediaType.video &&
            _playbackSettings.autoplayVideos,
        isLooping: previousMedia.type == MediaType.video &&
            _playbackSettings.loopVideos,
        currentMediaTags: previousTags,
      );

      _loopOverridden = false;

      // Initialize new media if video
      if (previousMedia.type == MediaType.video) {
        await _initializeVideoController(previousMedia);
      } else {
        await _disposeVideoController();
      }
    }
  }

  /// Toggles a [tag] assignment for the currently selected media item.
  Future<TagMutationResult> toggleTagOnCurrentMedia(TagEntity tag) async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) {
      return const TagMutationResult(TagMutationOutcome.unchanged);
    }

    final media = currentState.currentMedia;
    final hasTag = media.tagIds.contains(tag.id);

    try {
      if (hasTag) {
        await _assignTagUseCase.removeTagFromMedia(media.id, tag);
      } else {
        await _assignTagUseCase.assignTagToMedia(media.id, tag);
      }

      final updatedTagIds = hasTag
          ? media.tagIds.where((id) => id != tag.id).toList(growable: false)
          : [...media.tagIds, tag.id];

      final updatedMedia = media.copyWith(tagIds: List<String>.unmodifiable(updatedTagIds));
      final updatedMediaList = [...currentState.mediaList];
      updatedMediaList[currentState.currentIndex] = updatedMedia;

      final resolvedTags = await _tagLookup.getTagsByIds(updatedTagIds);
      final shortcutTags = await _buildShortcutTags(updatedMediaList);

      state = currentState.copyWith(
        mediaList: updatedMediaList,
        currentMediaTags: resolvedTags,
        shortcutTags: shortcutTags,
      );

      await _refreshTagCaches();

      return hasTag
          ? const TagMutationResult(TagMutationOutcome.removed)
          : const TagMutationResult(TagMutationOutcome.added);
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to toggle tag on media: $error');
      LoggingService.instance.debug('Toggle tag stack trace: $stackTrace');
      throw Exception('Failed to update tag "${tag.name}": $error');
    }
  }

  /// Replaces the current media's tag assignments with [tagIds].
  Future<TagUpdateResult> setTagsForCurrentMedia(List<String> tagIds) async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) {
      return const TagUpdateResult(addedCount: 0, removedCount: 0);
    }

    final media = currentState.currentMedia;
    final sanitizedTagIds = LinkedHashSet<String>.from(
      tagIds.where((id) => id.isNotEmpty),
    );
    final updatedTagIds = List<String>.unmodifiable(sanitizedTagIds);
    final previousTagSet = media.tagIds.toSet();
    final newTagSet = sanitizedTagIds;

    try {
      await _assignTagUseCase.setTagsForMedia([media.id], updatedTagIds);

      final updatedMedia = media.copyWith(tagIds: updatedTagIds);
      final updatedMediaList = [...currentState.mediaList];
      updatedMediaList[currentState.currentIndex] = updatedMedia;

      final resolvedTags = await _tagLookup.getTagsByIds(updatedTagIds);
      final shortcutTags = await _buildShortcutTags(updatedMediaList);

      state = currentState.copyWith(
        mediaList: updatedMediaList,
        currentMediaTags: resolvedTags,
        shortcutTags: shortcutTags,
      );

      await _refreshTagCaches();

      final addedCount = newTagSet.difference(previousTagSet).length;
      final removedCount = previousTagSet.difference(newTagSet).length;

      return TagUpdateResult(
        addedCount: addedCount,
        removedCount: removedCount,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to set tags for media: $error');
      LoggingService.instance.debug('Set tags stack trace: $stackTrace');
      throw Exception('Failed to save tags: $error');
    }
  }

  /// Toggle play/pause for video
  void togglePlayPause() {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      if (currentState.isPlaying) {
        _videoController?.pause();
      } else {
        _videoController?.play();
      }

      state = currentState.copyWith(isPlaying: !currentState.isPlaying);
    }
  }

  /// Toggle mute for video
  void toggleMute() {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      final newMuted = !currentState.isMuted;
      _videoController?.setVolume(newMuted ? 0.0 : 1.0);
      state = currentState.copyWith(isMuted: newMuted);
    }
  }

  /// Toggle loop for video
  void toggleLoop() {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      final newLooping = !currentState.isLooping;
      _videoController?.setLooping(newLooping);
      state = currentState.copyWith(isLooping: newLooping);
      _loopOverridden = true;
    }
  }

  /// Update the persisted playback preferences.
  void updatePlaybackPreferences(VideoPlaybackSettings settings) {
    _playbackSettings = settings;

    final currentState = state;
    if (_loopOverridden) return;

    if (currentState is FullScreenLoaded &&
        currentState.currentMedia.type == MediaType.video &&
        currentState.isLooping != settings.loopVideos) {
      _videoController?.setLooping(settings.loopVideos);
      state = currentState.copyWith(isLooping: settings.loopVideos);
    }
  }

  /// Seek to position in video
  void seekTo(Duration position) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      _videoController?.seekTo(position);
      state = currentState.copyWith(currentPosition: position);
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite() async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    try {
      await _favoritesViewModel.toggleFavorite(currentState.currentMedia);
      final newFavoriteStatus = !currentState.isFavorite;
      state = currentState.copyWith(isFavorite: newFavoriteStatus);
    } catch (e) {
      // Handle error - maybe show a snackbar
    }
  }

  /// Update video position (called by video player widget)
  void updateVideoPosition(Duration position) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    state = currentState.copyWith(currentPosition: position);
  }

  /// Update video duration (called by video player widget)
  void updateVideoDuration(Duration duration) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    state = currentState.copyWith(totalDuration: duration);
  }

  /// Update playing state
  void updatePlayingState(bool isPlaying) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    state = currentState.copyWith(isPlaying: isPlaying);
  }

  Future<List<TagEntity>> _buildShortcutTags(
    List<MediaEntity> mediaList,
  ) async {
    final rankedTagIds = _tagUsageRanker.rank(mediaList);
    if (rankedTagIds.isEmpty) {
      return const <TagEntity>[];
    }

    final resolvedTags = await _tagLookup.getTagsByIds(rankedTagIds);
    if (resolvedTags.isEmpty) {
      return const <TagEntity>[];
    }

    final tagsById = {
      for (final tag in resolvedTags) tag.id: tag,
    };

    return [
      for (final tagId in rankedTagIds)
        if (tagsById.containsKey(tagId)) tagsById[tagId]!,
    ];
  }

  Future<void> _refreshTagCaches() async {
    try {
      await _tagLookup.refresh();
    } catch (error, stackTrace) {
      LoggingService.instance
          .error('Failed to refresh tag lookup cache: $error');
      LoggingService.instance
          .debug('Tag lookup refresh stack trace: $stackTrace');
    }

    try {
      await _tagCacheRefresher.refresh();
    } catch (error, stackTrace) {
      LoggingService.instance
          .error('Failed to refresh tag view models: $error');
      LoggingService.instance
          .debug('Tag cache refresh stack trace: $stackTrace');
    }
  }

  /// Initialize video controller for the given media
  Future<void> _initializeVideoController(MediaEntity media) async {
    try {
      await _disposeVideoController();

      LoggingService.instance.debug('Initializing video controller', {
        'mediaId': media.id,
        'path': media.path,
      });

      final controller = VideoPlayerController.file(File(media.path));
      _videoController = controller;

      await controller.initialize();
      controller.addListener(_onVideoControllerUpdate);

      final currentState = state;
      if (currentState is FullScreenLoaded) {
        controller
          ..setLooping(currentState.isLooping)
          ..setVolume(currentState.isMuted ? 0.0 : 1.0);
      }

      _onVideoControllerUpdate();

      if (_playbackSettings.autoplayVideos) {
        await controller.play();
        final autoplayState = state;
        if (autoplayState is FullScreenLoaded) {
          state = autoplayState.copyWith(isPlaying: true);
        }
      }
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to initialize video controller: $error', {
        'path': media.path,
      });
      LoggingService.instance
          .debug('Video controller init stack trace: $stackTrace');

      await _disposeVideoController();

      final currentState = state;
      if (currentState is FullScreenLoaded) {
        state = currentState.copyWith(
          isPlaying: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
        );
      }
    }
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }

    LoggingService.instance.debug('Disposing video controller', {
      'isInitialized': controller.value.isInitialized,
    });

    controller.removeListener(_onVideoControllerUpdate);
    try {
      await controller.pause();
    } catch (_) {
      // Ignore pause errors when controller is not ready.
    }

    try {
      await controller.dispose();
    } catch (error) {
      LoggingService.instance.error('Error disposing video controller: $error');
    }

    _videoController = null;
  }

  /// Listener for video controller updates
  void _onVideoControllerUpdate() {
    if (_videoController == null) return;

    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isPlaying = _videoController!.value.isPlaying;

    updateVideoPosition(position);
    updateVideoDuration(duration);
    updatePlayingState(isPlaying);
  }

  /// Go to specific media by index
  Future<void> goToMedia(int index) async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (index < 0 || index >= currentState.mediaList.length) return;

    final targetMedia = currentState.mediaList[index];
    final isFavorite = await _favoritesRepository.isFavorite(targetMedia.id);
    final targetTags = await _tagLookup.getTagsByIds(targetMedia.tagIds);

    state = currentState.copyWith(
      currentIndex: index,
      isFavorite: isFavorite,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      isPlaying:
          targetMedia.type == MediaType.video && _playbackSettings.autoplayVideos,
      isLooping:
          targetMedia.type == MediaType.video && _playbackSettings.loopVideos,
      currentMediaTags: targetTags,
    );

    _loopOverridden = false;

    // Initialize new media if video
    if (targetMedia.type == MediaType.video) {
      await _initializeVideoController(targetMedia);
    } else {
      await _disposeVideoController();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeVideoController());
    super.dispose();
  }

  /// Helper method to check if an error is permission-related.
  bool _isPermissionError(String errorMessage) {
    return errorMessage.contains('Operation not permitted') ||
           errorMessage.contains('errno = 1') ||
           errorMessage.contains('Permission denied') ||
           errorMessage.contains('FileSystemError');
  }
}

/// Outcome of a tag toggle operation.
enum TagMutationOutcome { added, removed, unchanged }

/// Result describing the outcome of a single tag toggle.
class TagMutationResult {
  const TagMutationResult(this.outcome);

  final TagMutationOutcome outcome;
}

/// Summary describing how many tags were added or removed by a batch update.
class TagUpdateResult {
  const TagUpdateResult({required this.addedCount, required this.removedCount});

  final int addedCount;
  final int removedCount;

  bool get hasChanges => addedCount > 0 || removedCount > 0;
}

/// Provider for FullScreenViewModel
final fullScreenViewModelProvider =
    StateNotifierProvider.autoDispose<FullScreenViewModel, FullScreenState>(
  (ref) {
    final viewModel = FullScreenViewModel(
      ref.watch(loadMediaForViewingUseCaseProvider),
      ref.read(favoritesViewModelProvider.notifier),
      ref.watch(favoritesRepositoryProvider),
      ref.watch(assignTagUseCaseProvider),
      ref.watch(tagLookupProvider),
      ref.watch(tagCacheRefresherProvider),
      ref.read(videoPlaybackSettingsProvider),
    );

    ref.listen<VideoPlaybackSettings>(
      videoPlaybackSettingsProvider,
      (previous, next) {
        viewModel.updatePlaybackPreferences(next);
      },
    );

    return viewModel;
  },
);
