import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/use_cases/load_media_for_viewing_use_case.dart';
import '../../domain/entities/viewer_state_entity.dart';
import '../../../../core/services/logging_service.dart';

/// ViewModel for full-screen media viewing
class FullScreenViewModel extends StateNotifier<FullScreenState> {
  FullScreenViewModel(
    this._loadMediaUseCase,
    this._favoritesViewModel,
    this._favoritesRepository,
  ) : super(const FullScreenInitial());

  final LoadMediaForViewingUseCase _loadMediaUseCase;
  final FavoritesViewModel _favoritesViewModel;
  final FavoritesRepository _favoritesRepository;

  VideoPlayerController? _videoController;

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

      // Check if current media is favorite
      final isFavorite = await _favoritesRepository.isFavorite(
        finalMediaList[currentIndex].id,
      );

      Future(() {
        state = FullScreenLoaded(
          mediaList: finalMediaList,
          currentIndex: currentIndex,
          isPlaying: false,
          isMuted: false,
          isLooping: false,
          currentPosition: Duration.zero,
          totalDuration: Duration.zero,
          isFavorite: isFavorite,
        );
      });

      // Initialize video controller if current media is video
      if (finalMediaList[currentIndex].type == MediaType.video) {
        await _initializeVideoController(finalMediaList[currentIndex]);
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

      state = currentState.copyWith(
        currentIndex: newIndex,
        isFavorite: isFavorite,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlaying: false,
      );

      // Initialize new media if video
      if (nextMedia.type == MediaType.video) {
        await _initializeVideoController(nextMedia);
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

      state = currentState.copyWith(
        currentIndex: newIndex,
        isFavorite: isFavorite,
        currentPosition: Duration.zero,
        totalDuration: Duration.zero,
        isPlaying: false,
      );

      // Initialize new media if video
      if (previousMedia.type == MediaType.video) {
        await _initializeVideoController(previousMedia);
      }
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

  /// Initialize video controller for the given media
  Future<void> _initializeVideoController(MediaEntity media) async {
    // Dispose existing controller
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }

    // Create new controller
    _videoController = VideoPlayerController.file(File(media.path));

    // Initialize the controller
    await _videoController!.initialize();

    // Add listener for updates
    _videoController!.addListener(_onVideoControllerUpdate);

    // Set initial state values
    final currentState = state;
    if (currentState is FullScreenLoaded) {
      _videoController!.setLooping(currentState.isLooping);
      _videoController!.setVolume(currentState.isMuted ? 0.0 : 1.0);
    }
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

    state = currentState.copyWith(
      currentIndex: index,
      isFavorite: isFavorite,
      currentPosition: Duration.zero,
      totalDuration: Duration.zero,
      isPlaying: false,
    );

    // Initialize new media if video
    if (targetMedia.type == MediaType.video) {
      await _initializeVideoController(targetMedia);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
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

/// Provider for FullScreenViewModel
final fullScreenViewModelProvider =
    StateNotifierProvider.autoDispose<FullScreenViewModel, FullScreenState>(
       (ref) => FullScreenViewModel(
         ref.watch(loadMediaForViewingUseCaseProvider),
         ref.read(favoritesViewModelProvider.notifier),
         ref.watch(favoritesRepositoryProvider),
       ),
     );
