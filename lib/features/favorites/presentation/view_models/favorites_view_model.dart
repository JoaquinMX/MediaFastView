import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/data/data_sources/isar_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../core/services/logging_service.dart';

/// Sealed class representing the state of favorites.
sealed class FavoritesState {
  const FavoritesState();
}

/// Initial state before any favorites have been loaded.
class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

/// Loading state when favorites are being fetched.
class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

/// Loaded state with favorites data.
class FavoritesLoaded extends FavoritesState {
  const FavoritesLoaded({required this.favorites, required this.media});

  final List<String> favorites;
  final List<MediaEntity> media;

  FavoritesLoaded copyWith({
    List<String>? favorites,
    List<MediaEntity>? media,
  }) {
    return FavoritesLoaded(
      favorites: favorites ?? this.favorites,
      media: media ?? this.media,
    );
  }
}

/// Error state when an operation fails.
class FavoritesError extends FavoritesState {
  const FavoritesError(this.message);

  final String message;
}

/// Empty state when no favorites are available.
class FavoritesEmpty extends FavoritesState {
  const FavoritesEmpty();
}

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

/// ViewModel for managing favorites state and operations.
class FavoritesViewModel extends StateNotifier<FavoritesState> {
  FavoritesViewModel(this._favoritesRepository, this._mediaDataSource)
    : super(const FavoritesInitial());

  final FavoritesRepository _favoritesRepository;
  final IsarMediaDataSource _mediaDataSource;
  bool _hasLoadedFavorites = false;

  /// Tracks whether an initial load has completed.
  bool get hasLoadedFavorites => _hasLoadedFavorites;

  /// Loads favorites and their corresponding media.
  Future<void> loadFavorites() async {
    state = const FavoritesLoading();
    try {
      final favoriteIds = await _favoritesRepository.getFavoriteMediaIds();
      LoggingService.instance.info(
        'Loaded ${favoriteIds.length} favorite IDs: $favoriteIds',
      );
      if (!mounted) {
        return;
      }
      if (favoriteIds.isEmpty) {
        LoggingService.instance.info('No favorites found, setting empty state');
        state = const FavoritesEmpty();
        return;
      }

      // Get media entities for favorite IDs
      final media = await _getMediaForFavorites(favoriteIds);
      if (!mounted) {
        return;
      }
      if (media.isEmpty) {
        LoggingService.instance.warning(
          'No media found for favorite IDs, setting empty state',
        );
        state = const FavoritesEmpty();
      } else {
        LoggingService.instance.info(
          'Setting loaded state with ${media.length} media items',
        );
        state = FavoritesLoaded(favorites: favoriteIds, media: media);
      }
    } catch (e) {
      LoggingService.instance.error('Error loading favorites: $e');
      if (!mounted) {
        return;
      }
      state = FavoritesError(e.toString());
    } finally {
      _hasLoadedFavorites = true;
    }
  }

  /// Toggles favorite status for a media item.
  Future<void> toggleFavorite(MediaEntity media) async {
    try {
      final isCurrentlyFavorite = await _favoritesRepository.isFavorite(
        media.id,
      );
      if (!mounted) {
        return;
      }

      if (isCurrentlyFavorite) {
        await _favoritesRepository.removeFavorite(media.id);
      } else {
        await _favoritesRepository.addFavorite(media.id);
        // Ensure media is persisted when adding to favorites
        await _persistMedia(media);
      }

      if (!mounted) {
        return;
      }

      // Reload favorites after toggle
      await loadFavorites();
    } catch (e) {
      if (!mounted) {
        return;
      }
      state = FavoritesError(e.toString());
    }
  }

  /// Checks if a media item is favorited.
  Future<bool> isFavorite(String mediaId) async {
    try {
      return await _favoritesRepository.isFavorite(mediaId);
    } catch (e) {
      return false;
    }
  }

  /// Checks the in-memory state for a favorite.
  bool isFavoriteInState(String mediaId) {
    final currentState = state;
    if (currentState is FavoritesLoaded) {
      return currentState.favorites.contains(mediaId);
    }
    return false;
  }

  /// Clears all favorites.
  Future<void> clearAllFavorites() async {
    try {
      final favoriteIds = await _favoritesRepository.getFavoriteMediaIds();
      for (final favoriteId in favoriteIds) {
        await _favoritesRepository.removeFavorite(favoriteId);
      }
      // Reload favorites to update the state
      await loadFavorites();
    } catch (e) {
      state = FavoritesError('Failed to clear favorites: $e');
    }
  }

  /// Persists a media entity to local storage.
  Future<void> _persistMedia(MediaEntity media) async {
    final model = MediaModel(
      id: media.id,
      path: media.path,
      name: media.name,
      type: media.type,
      size: media.size,
      lastModified: media.lastModified,
      tagIds: media.tagIds,
      directoryId: media.directoryId,
      bookmarkData: media.bookmarkData,
      thumbnailPath: media.thumbnailPath,
      width: media.width,
      height: media.height,
      durationSeconds:
          media.duration == null ? null : media.duration!.inMilliseconds / 1000,
      metadata: media.metadata,
    );
    await _mediaDataSource.upsertMedia([model]);
  }

  /// Helper method to get media entities for favorite IDs.
  Future<List<MediaEntity>> _getMediaForFavorites(
    List<String> favoriteIds,
  ) async {
    LoggingService.instance.info(
      'Loading media for ${favoriteIds.length} favorite IDs: $favoriteIds',
    );

    // Get all stored media from SharedPreferences
    final allStoredMedia = await _mediaDataSource.getMedia();
    LoggingService.instance.info(
      'Found ${allStoredMedia.length} stored media items',
    );

    // Create a map for fast lookup by ID
    final mediaMap = {for (final media in allStoredMedia) media.id: media};

    // Find media entities for favorite IDs
    final validMedia = <MediaEntity>[];
    for (final id in favoriteIds) {
      final storedMedia = mediaMap[id];
      if (storedMedia != null) {
        // Convert MediaModel to MediaEntity
        final mediaEntity = MediaEntity(
          id: storedMedia.id,
          path: storedMedia.path,
          name: storedMedia.name,
          type: storedMedia.type,
          size: storedMedia.size,
          lastModified: storedMedia.lastModified,
          tagIds: storedMedia.tagIds,
          directoryId: storedMedia.directoryId,
          bookmarkData: storedMedia.bookmarkData,
          thumbnailPath: storedMedia.thumbnailPath,
          width: storedMedia.width,
          height: storedMedia.height,
          duration: storedMedia.durationSeconds == null
              ? null
              : Duration(
                  milliseconds:
                      (storedMedia.durationSeconds! * 1000).round(),
                ),
          metadata: storedMedia.metadata,
        );
        validMedia.add(mediaEntity);
        LoggingService.instance.debug(
          'Successfully loaded media for ID $id: ${mediaEntity.name}, path: ${mediaEntity.path}',
        );
      } else {
        LoggingService.instance.warning(
          'No stored media found for favorite ID $id',
        );
      }
    }

    LoggingService.instance.info(
      'Loaded ${validMedia.length} valid media entities out of ${favoriteIds.length} favorites',
    );
    return validMedia;
  }
}

/// Provider for FavoritesViewModel with auto-dispose.
final favoritesViewModelProvider =
    StateNotifierProvider.autoDispose<FavoritesViewModel, FavoritesState>(
      (ref) {
        final viewModel = FavoritesViewModel(
          ref.watch(favoritesRepositoryProvider),
          ref.watch(mediaDataSourceProvider),
        );
        viewModel.loadFavorites();
        return viewModel;
      },
    );
