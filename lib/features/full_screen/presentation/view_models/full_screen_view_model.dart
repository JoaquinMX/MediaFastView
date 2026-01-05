import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/models/directory_navigation_target.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../../tagging/presentation/view_models/tag_management_view_model.dart';
import '../../../tagging/presentation/view_models/tags_view_model.dart';
import '../../../settings/domain/entities/playback_settings.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/providers/tag_shortcut_preferences_provider.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/tag_cache_refresher.dart';
import '../../../../shared/utils/tag_lookup.dart';
import '../../../../shared/utils/tag_mutation_service.dart';
import '../../../../shared/utils/tag_shortcut_preferences.dart';
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
    this._tagShortcutPreferences,
    PlaybackSettings playbackSettings, {
    TagMutationService? tagMutationService,
    TagUsageRanker? tagUsageRanker,
  })  : _playbackSettings = playbackSettings,
        _tagMutationService = tagMutationService ??
            TagMutationService(
              assignTagUseCase: _assignTagUseCase,
              tagLookup: _tagLookup,
              tagCacheRefresher: _tagCacheRefresher,
            ),
        _tagUsageRanker = tagUsageRanker ?? const TagUsageRanker(),
        super(const FullScreenInitial());

  final LoadMediaForViewingUseCase _loadMediaUseCase;
  final FavoritesViewModel _favoritesViewModel;
  final FavoritesRepository _favoritesRepository;
  final AssignTagUseCase _assignTagUseCase;
  final TagLookup _tagLookup;
  final TagCacheRefresher _tagCacheRefresher;
  final TagShortcutPreferences _tagShortcutPreferences;
  final TagMutationService _tagMutationService;
  final TagUsageRanker _tagUsageRanker;

  PlaybackSettings _playbackSettings;
  bool _loopOverridden = false;
  DirectoryNavigationTarget? _currentDirectory;
  List<DirectoryNavigationTarget> _siblingDirectories = const [];
  int _currentDirectoryIndex = 0;

  DirectoryNavigationTarget? get currentDirectory => _currentDirectory;
  int get currentDirectoryIndex => _currentDirectoryIndex;
  List<DirectoryNavigationTarget> get siblingDirectories =>
      List<DirectoryNavigationTarget>.unmodifiable(_siblingDirectories);

  DirectoryNavigationTarget? _nextDirectoryTarget() {
    if (_siblingDirectories.isEmpty) return null;
    final nextIndex = _currentDirectoryIndex + 1;
    if (nextIndex >= _siblingDirectories.length) return null;
    return _siblingDirectories[nextIndex];
  }

  DirectoryNavigationTarget? _previousDirectoryTarget() {
    if (_siblingDirectories.isEmpty) return null;
    final previousIndex = _currentDirectoryIndex - 1;
    if (previousIndex < 0) return null;
    return _siblingDirectories[previousIndex];
  }

  Future<void> navigateToDirectoryTarget(
    DirectoryNavigationTarget target, {
    bool startAtEnd = false,
  }) async {
    if (_siblingDirectories.isEmpty ||
        !_siblingDirectories.any((directory) => directory.path == target.path)) {
      _siblingDirectories = [..._siblingDirectories, target];
    }

    final resolvedIndex = _siblingDirectories.indexWhere(
      (directory) => directory.path == target.path,
    );

    _currentDirectoryIndex = resolvedIndex == -1 ? 0 : resolvedIndex;
    _currentDirectory = target;

    await initialize(
      target.path,
      directoryName: target.name,
      bookmarkData: target.bookmarkData,
      siblingDirectories: _siblingDirectories,
      currentDirectoryIndex: _currentDirectoryIndex,
      startAtEnd: startAtEnd,
    );
  }

  void _applyNavigationContext(
    String directoryPath, {
    String? directoryName,
    String? bookmarkData,
    List<DirectoryNavigationTarget>? siblingDirectories,
    int? currentIndex,
  }) {
    _siblingDirectories = List<DirectoryNavigationTarget>.from(
      siblingDirectories ?? _siblingDirectories,
    );

    if (_siblingDirectories.isNotEmpty) {
      final resolvedIndex = currentIndex ??
          _siblingDirectories.indexWhere(
            (directory) => directory.path == directoryPath,
          );

      final safeIndex = (resolvedIndex == -1 ? 0 : resolvedIndex)
          .clamp(0, _siblingDirectories.length - 1);
      _currentDirectoryIndex = safeIndex;
      _currentDirectory = _siblingDirectories[_currentDirectoryIndex];
    } else {
      _currentDirectory = DirectoryNavigationTarget(
        path: directoryPath,
        name: directoryName ?? directoryPath.split('/').last,
        bookmarkData: bookmarkData,
      );
      _currentDirectoryIndex = 0;
    }
  }

  /// Initialize the viewer with media from a directory or provided media list
  Future<void> initialize(
    String directoryPath, {
    String? directoryName,
    String? initialMediaId,
    String? bookmarkData,
    List<MediaEntity>? mediaList,
    List<DirectoryNavigationTarget>? siblingDirectories,
    int? currentDirectoryIndex,
    int? initialIndex,
    bool startAtEnd = false,
  }) async {
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

      _applyNavigationContext(
        directoryPath,
        bookmarkData: bookmarkData,
        directoryName: directoryName,
        siblingDirectories: siblingDirectories,
        currentIndex: currentDirectoryIndex,
      );

      final requestedIndex = initialMediaId != null
          ? finalMediaList.indexWhere((media) => media.id == initialMediaId)
          : (startAtEnd ? finalMediaList.length - 1 : (initialIndex ?? 0));

      if (initialMediaId != null && requestedIndex == -1) {
        Future(() {
          state = const FullScreenError('Initial media not found');
        });
        return;
      }

      final currentIndex = requestedIndex.clamp(0, finalMediaList.length - 1);
      final currentMedia = finalMediaList[currentIndex];
      final isVideo = currentMedia.type == MediaType.video;

      // Check if current media is favorite
      final isFavorite = await _favoritesRepository.isFavorite(
        currentMedia.id,
      );

      _loopOverridden = false;

      final currentTags = await _tagLookup.getTagsByIds(currentMedia.tagIds);
      final allTags = await _tagLookup.getAllTags();
      final shortcutTags = await _buildShortcutTags(finalMediaList);

      Future(() {
        state = FullScreenLoaded(
          mediaList: finalMediaList,
          currentIndex: currentIndex,
          isPlaying: isVideo && _playbackSettings.autoplayVideos,
          isMuted: false,
          isLooping: isVideo && _playbackSettings.loopVideos,
          playbackSpeed: 1.0,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isFavorite: isFavorite,
          currentMediaTags: currentTags,
          allTags: allTags,
          shortcutTags: shortcutTags,
        );
      });

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
  Future<NavigationAttemptResult> nextMedia() async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) {
      return const NavigationAttemptResult(mediaAdvanced: false);
    }

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

      return const NavigationAttemptResult(mediaAdvanced: true);
    }

    return NavigationAttemptResult(
      mediaAdvanced: false,
      directoryTarget: _nextDirectoryTarget(),
    );
  }

  /// Navigate to previous media
  Future<NavigationAttemptResult> previousMedia() async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) {
      return const NavigationAttemptResult(mediaAdvanced: false);
    }

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

      return const NavigationAttemptResult(mediaAdvanced: true);
    }

    return NavigationAttemptResult(
      mediaAdvanced: false,
      directoryTarget: _previousDirectoryTarget(),
    );
  }

  /// Toggles a [tag] assignment for the currently selected media item.
  Future<TagMutationResult> toggleTagOnCurrentMedia(TagEntity tag) async {
    final currentState = state;
    if (currentState is! FullScreenLoaded) {
      return const TagMutationResult(outcome: TagMutationOutcome.unchanged);
    }

    try {
      final result = await _tagMutationService.toggleTagForMedia(
        currentState.currentMedia,
        tag,
      );

      if (result.updatedMedia == null) {
        return const TagMutationResult(outcome: TagMutationOutcome.unchanged);
      }

      final updatedMediaList = [...currentState.mediaList];
      updatedMediaList[currentState.currentIndex] = result.updatedMedia!;
      final shortcutTags = await _buildShortcutTags(updatedMediaList);

      state = currentState.copyWith(
        mediaList: updatedMediaList,
        currentMediaTags: result.resolvedTags,
        shortcutTags: shortcutTags,
      );

      return result;
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
      state = currentState.copyWith(isPlaying: !currentState.isPlaying);
    }
  }

  /// Toggle mute for video
  void toggleMute() {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      final newMuted = !currentState.isMuted;
      state = currentState.copyWith(isMuted: newMuted);
    }
  }

  /// Toggle loop for video
  void toggleLoop() {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
      final newLooping = !currentState.isLooping;
      state = currentState.copyWith(isLooping: newLooping);
      _loopOverridden = true;
    }
  }

  /// Update playback speed for the current video.
  void setPlaybackSpeed(double speed) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video && speed > 0) {
      state = currentState.copyWith(playbackSpeed: speed);
    }
  }

  /// Update the persisted playback preferences.
  void updatePlaybackPreferences(PlaybackSettings settings) {
    _playbackSettings = settings;

    final currentState = state;
    if (_loopOverridden) return;

    if (currentState is FullScreenLoaded &&
        currentState.currentMedia.type == MediaType.video &&
        currentState.isLooping != settings.loopVideos) {
      state = currentState.copyWith(isLooping: settings.loopVideos);
    }
  }

  /// Seek to position in video
  void seekTo(Duration position) {
    final currentState = state;
    if (currentState is! FullScreenLoaded) return;

    if (currentState.currentMedia.type == MediaType.video) {
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
    final configuredShortcuts = await _tagShortcutPreferences.loadShortcutTagIds();
    final rankedTagIds = _tagUsageRanker.rank(mediaList);

    final mergedTagIds = <String>[
      ...configuredShortcuts,
      ...rankedTagIds.where((id) => !configuredShortcuts.contains(id)),
    ].take(TagUsageRanker.defaultLimit).toList();

    if (mergedTagIds.isEmpty) {
      return const <TagEntity>[];
    }

    final resolvedTags = await _tagLookup.getTagsByIds(mergedTagIds);
    if (resolvedTags.isEmpty) {
      return const <TagEntity>[];
    }

    final tagsById = {
      for (final tag in resolvedTags) tag.id: tag,
    };

    return [
      for (final tagId in mergedTagIds)
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

  }

  /// Helper method to check if an error is permission-related.
  bool _isPermissionError(String errorMessage) {
    return errorMessage.contains('Operation not permitted') ||
        errorMessage.contains('errno = 1') ||
        errorMessage.contains('Permission denied') ||
        errorMessage.contains('FileSystemError');
  }
}

/// Summary describing how many tags were added or removed by a batch update.
class TagUpdateResult {
  const TagUpdateResult({required this.addedCount, required this.removedCount});

  final int addedCount;
  final int removedCount;

  bool get hasChanges => addedCount > 0 || removedCount > 0;
}

/// Result of attempting to move to the next or previous media item.
class NavigationAttemptResult {
  const NavigationAttemptResult({
    required this.mediaAdvanced,
    this.directoryTarget,
  });

  final bool mediaAdvanced;
  final DirectoryNavigationTarget? directoryTarget;

  bool get hasDirectoryOption => directoryTarget != null;
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
      ref.watch(tagShortcutPreferencesProvider),
      ref.read(videoPlaybackSettingsProvider),
      tagMutationService: ref.watch(tagMutationServiceProvider),
    );

    ref.listen<PlaybackSettings>(
      videoPlaybackSettingsProvider,
      (previous, next) {
        viewModel.updatePlaybackPreferences(next);
      },
    );

    return viewModel;
  },
);
