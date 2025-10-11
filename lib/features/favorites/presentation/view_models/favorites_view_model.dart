import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/favorite_entity.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/data/data_sources/local_media_data_source.dart';
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
  final SharedPreferencesMediaDataSource _mediaDataSource;
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
    await toggleFavoritesForMedia([media]);
  }

  /// Toggles favorites for a collection of media items.
  Future<FavoritesBatchResult> toggleFavoritesForMedia(
    List<MediaEntity> mediaItems,
  ) async {
    if (mediaItems.isEmpty) {
      return const FavoritesBatchResult.empty();
    }

    try {
      final additions = <FavoriteEntity>[];
      final removals = <String>[];
      final mediaById = {for (final media in mediaItems) media.id: media};

      for (final media in mediaItems) {
        final isFavorited = await _favoritesRepository.isFavorite(
          media.id,
          type: FavoriteItemType.media,
        );
        if (isFavorited) {
          removals.add(media.id);
        } else {
          additions.add(
            FavoriteEntity(
              itemId: media.id,
              itemType: FavoriteItemType.media,
              addedAt: DateTime.now(),
              metadata: {
                'name': media.name,
                'path': media.path,
                'type': media.type.name,
              },
            ),
          );
        }
      }

      if (additions.isNotEmpty) {
        await _favoritesRepository.addFavorites(additions);
        await Future.wait(
          additions.map(
            (favorite) async {
              final media = mediaById[favorite.itemId];
              if (media != null) {
                await _persistMedia(media);
              }
            },
          ),
        );
      }

      if (removals.isNotEmpty) {
        await _favoritesRepository.removeFavorites(removals);
      }

      if (!mounted) {
        return FavoritesBatchResult(
          added: additions.length,
          removed: removals.length,
        );
      }

      if (additions.isNotEmpty || removals.isNotEmpty) {
        await loadFavorites();
      }

      return FavoritesBatchResult(
        added: additions.length,
        removed: removals.length,
      );
    } catch (e) {
      if (mounted) {
        state = FavoritesError(e.toString());
      }
      return const FavoritesBatchResult.empty();
    }
  }

  /// Toggles favorites for directory entities.
  Future<FavoritesBatchResult> toggleFavoritesForDirectories(
    List<DirectoryEntity> directories,
  ) async {
    if (directories.isEmpty) {
      return const FavoritesBatchResult.empty();
    }

    try {
      final additions = <FavoriteEntity>[];
      final removals = <String>[];

      for (final directory in directories) {
        final isFavorited = await _favoritesRepository.isFavorite(
          directory.id,
          type: FavoriteItemType.directory,
        );
        if (isFavorited) {
          removals.add(directory.id);
        } else {
          additions.add(
            FavoriteEntity(
              itemId: directory.id,
              itemType: FavoriteItemType.directory,
              addedAt: DateTime.now(),
              metadata: {
                'name': directory.name,
                'path': directory.path,
              },
            ),
          );
        }
      }

      if (additions.isNotEmpty) {
        await _favoritesRepository.addFavorites(additions);
      }

      if (removals.isNotEmpty) {
        await _favoritesRepository.removeFavorites(removals);
      }

      if (!mounted) {
        return FavoritesBatchResult(
          added: additions.length,
          removed: removals.length,
        );
      }

      if (additions.isNotEmpty || removals.isNotEmpty) {
        await loadFavorites();
      }

      return FavoritesBatchResult(
        added: additions.length,
        removed: removals.length,
      );
    } catch (e) {
      if (mounted) {
        state = FavoritesError(e.toString());
      }
      return const FavoritesBatchResult.empty();
    }
  }

  /// Checks if a media item is favorited.
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async {
    try {
      return await _favoritesRepository.isFavorite(itemId, type: type);
    } catch (e) {
      return false;
    }
  }

  /// Checks the in-memory state for a favorite.
  bool isFavoriteInState(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) {
    final currentState = state;
    if (currentState is FavoritesLoaded) {
      if (type != FavoriteItemType.media) {
        return false;
      }
      return currentState.favorites.contains(itemId);
    }
    return false;
  }

  /// Clears all favorites.
  Future<void> clearAllFavorites() async {
    try {
      final favorites = await _favoritesRepository.getFavorites();
      if (favorites.isEmpty) {
        if (mounted) {
          state = const FavoritesEmpty();
        }
        return;
      }

      await _favoritesRepository
          .removeFavorites(favorites.map((fav) => fav.itemId).toList());
      // Reload favorites to update the state
      if (mounted) {
        await loadFavorites();
      }
    } catch (e) {
      if (mounted) {
        state = FavoritesError('Failed to clear favorites: $e');
      }
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

/// Result describing the outcome of a batch favorites toggle.
class FavoritesBatchResult {
  const FavoritesBatchResult({required this.added, required this.removed});

  const FavoritesBatchResult.empty()
    : added = 0,
      removed = 0;

  final int added;
  final int removed;

  bool get hasChanges => added > 0 || removed > 0;
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
