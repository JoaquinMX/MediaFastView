import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/logging_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/favorite_entity.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/use_cases/favorite_media_use_case.dart';

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
  const FavoritesLoaded({
    required this.favorites,
    required this.media,
    required this.directoryFavorites,
  });

  final List<String> favorites;
  final List<MediaEntity> media;
  final List<String> directoryFavorites;

  FavoritesLoaded copyWith({
    List<String>? favorites,
    List<MediaEntity>? media,
    List<String>? directoryFavorites,
  }) {
    return FavoritesLoaded(
      favorites: favorites ?? this.favorites,
      media: media ?? this.media,
      directoryFavorites: directoryFavorites ?? this.directoryFavorites,
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
  FavoritesViewModel(
    this._favoritesRepository,
    this._favoriteMediaUseCase,
  ) : super(const FavoritesInitial());

  final FavoritesRepository _favoritesRepository;
  final FavoriteMediaUseCase _favoriteMediaUseCase;
  bool _hasLoadedFavorites = false;

  /// Tracks whether an initial load has completed.
  bool get hasLoadedFavorites => _hasLoadedFavorites;

  /// Loads favorites and their corresponding media.
  Future<void> loadFavorites() async {
    state = const FavoritesLoading();
    try {
      final favoriteIds = await _favoritesRepository.getFavoriteMediaIds();
      final directoryFavoriteIds =
          await _favoritesRepository.getFavoriteDirectoryIds();
      LoggingService.instance.info(
        'Loaded ${favoriteIds.length} favorite IDs: $favoriteIds',
      );
      if (!mounted) {
        return;
      }
      if (favoriteIds.isEmpty && directoryFavoriteIds.isEmpty) {
        LoggingService.instance.info('No favorites found, setting empty state');
        state = const FavoritesEmpty();
        return;
      }

      // Get media entities for favorite IDs
      final media = favoriteIds.isEmpty
          ? const <MediaEntity>[]
          : await _favoriteMediaUseCase.resolveMediaForFavorites(favoriteIds);
      if (!mounted) {
        return;
      }
      if (media.isEmpty && favoriteIds.isNotEmpty) {
        LoggingService.instance.warning(
          'No media found for favorite IDs, setting media list empty',
        );
      }
      LoggingService.instance.info(
        'Setting loaded state with ${media.length} media items and '
        '${directoryFavoriteIds.length} directory favorites',
      );
      state = FavoritesLoaded(
        favorites: favoriteIds,
        media: media,
        directoryFavorites: directoryFavoriteIds,
      );
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

      final favoriteStatuses = <String, bool>{};
      for (final media in mediaItems) {
        final isFavorited = await _favoritesRepository.isFavorite(
          media.id,
          type: FavoriteItemType.media,
        );
        favoriteStatuses[media.id] = isFavorited;
      }

      final allSelectedAreFavorites =
          favoriteStatuses.values.every((isFavorite) => isFavorite);

      if (allSelectedAreFavorites) {
        removals.addAll(favoriteStatuses.keys);
      } else {
        for (final media in mediaItems) {
          final isFavorited = favoriteStatuses[media.id] ?? false;
          if (!isFavorited) {
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
      }

      if (additions.isNotEmpty) {
        await _favoritesRepository.addFavorites(additions);
        await Future.wait(
          additions.map(
            (favorite) async {
              final media = mediaById[favorite.itemId];
              if (media != null) {
                await _favoriteMediaUseCase.persistMedia(media);
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
        _refreshFavoritesInBackground();
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
        _refreshFavoritesInBackground();
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

  void _refreshFavoritesInBackground() {
    unawaited(() async {
      try {
        await loadFavorites();
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to refresh favorites: $e', 

        );
      }
    }());
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
      return switch (type) {
        FavoriteItemType.media => currentState.favorites.contains(itemId),
        FavoriteItemType.directory =>
            currentState.directoryFavorites.contains(itemId),
      };
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
          ref.watch(favoriteMediaUseCaseProvider),
        );
        viewModel.loadFavorites();
        return viewModel;
      },
    );
