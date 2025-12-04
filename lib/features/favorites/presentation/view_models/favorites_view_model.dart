import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/favorite_entity.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/use_cases/get_media_use_case.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/recursive_directory_actions_provider.dart';
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
    this._directoryRepository,
    this._mediaDataSource,
    this._getMediaUseCase,
    this._applyDirectoryActionsRecursively,
  ) : super(const FavoritesInitial());

  final FavoritesRepository _favoritesRepository;
  final DirectoryRepository _directoryRepository;
  final IsarMediaDataSource _mediaDataSource;
  final GetMediaUseCase _getMediaUseCase;
  final bool _applyDirectoryActionsRecursively;
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
          : await _getMediaForFavorites(favoriteIds);
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

  Future<({List<FavoriteEntity> additions, List<String> removals})>
      _buildRecursiveFavoriteChanges({
    required List<DirectoryEntity> directoriesToAdd,
    required List<DirectoryEntity> directoriesToRemove,
  }) async {
    if (!_applyDirectoryActionsRecursively ||
        (directoriesToAdd.isEmpty && directoriesToRemove.isEmpty)) {
      return (additions: const <FavoriteEntity>[], removals: const <String>[]);
    }

    final expandedAddIds = await _expandDirectoryIdsRecursively(directoriesToAdd);
    final expandedRemoveIds =
        await _expandDirectoryIdsRecursively(directoriesToRemove);

    // Favor additions when the same path is present in both lists.
    expandedRemoveIds.removeWhere(expandedAddIds.contains);

    final targetIds = {...expandedAddIds, ...expandedRemoveIds};
    if (targetIds.isEmpty) {
      return (additions: const <FavoriteEntity>[], removals: const <String>[]);
    }

    final media = await _collectMediaForDirectories(targetIds);
    final additions = <FavoriteEntity>[];
    final removals = <String>[];

    for (final item in media) {
      if (expandedAddIds.contains(item.directoryId)) {
        final isFavorite = await _favoritesRepository.isFavorite(item.id);
        if (!isFavorite) {
          additions.add(
            FavoriteEntity(
              itemId: item.id,
              itemType: FavoriteItemType.media,
              addedAt: DateTime.now(),
              metadata: {
                'name': item.name,
                'path': item.path,
              },
            ),
          );
          await _persistMedia(item);
        }
      } else if (expandedRemoveIds.contains(item.directoryId)) {
        removals.add(item.id);
      }
    }

    return (additions: additions, removals: removals);
  }

  Future<Set<String>> _expandDirectoryIdsRecursively(
    List<DirectoryEntity> roots,
  ) async {
    if (roots.isEmpty) {
      return <String>{};
    }

    final normalizedRoots = roots
        .map(
          (dir) => (
            id: dir.id,
            path: _normalizePath(dir.path),
          ),
        )
        .toList(growable: false);

    final allDirectories = await _directoryRepository.getDirectories();
    final expanded = <String>{};

    for (final directory in allDirectories) {
      final normalizedPath = _normalizePath(directory.path);
      final isWithinRoot = normalizedRoots.any(
        (root) =>
            p.equals(root.path, normalizedPath) ||
            p.isWithin(root.path, normalizedPath),
      );

      if (isWithinRoot) {
        expanded.add(directory.id);
      }
    }

    return expanded;
  }

  Future<List<MediaEntity>> _collectMediaForDirectories(
    Set<String> directoryIds,
  ) async {
    if (directoryIds.isEmpty) {
      return const <MediaEntity>[];
    }

    final allMedia = await _getMediaUseCase.entireLibrary();
    return allMedia
        .where((media) => directoryIds.contains(media.directoryId))
        .toList();
  }

  String _normalizePath(String path) => p.normalize(path.trim());

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
      final directoriesToAdd = <DirectoryEntity>[];
      final directoriesToRemove = <DirectoryEntity>[];

      for (final directory in directories) {
        final isFavorited = await _favoritesRepository.isFavorite(
          directory.id,
          type: FavoriteItemType.directory,
        );
        if (isFavorited) {
          removals.add(directory.id);
          directoriesToRemove.add(directory);
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
          directoriesToAdd.add(directory);
        }
      }

      final recursiveChanges = await _buildRecursiveFavoriteChanges(
        directoriesToAdd: directoriesToAdd,
        directoriesToRemove: directoriesToRemove,
      );

      if (additions.isNotEmpty || recursiveChanges.additions.isNotEmpty) {
        await _favoritesRepository.addFavorites(
          [...additions, ...recursiveChanges.additions],
        );
      }

      if (removals.isNotEmpty || recursiveChanges.removals.isNotEmpty) {
        await _favoritesRepository.removeFavorites(
          [...removals, ...recursiveChanges.removals],
        );
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

  MediaEntity _mediaModelToEntity(MediaModel media) {
    return MediaEntity(
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
  }

  /// Helper method to get media entities for favorite IDs.
  Future<List<MediaEntity>> _getMediaForFavorites(
    List<String> favoriteIds,
  ) async {
    LoggingService.instance.info(
      'Loading media for ${favoriteIds.length} favorite IDs: $favoriteIds',
    );

    if (favoriteIds.isEmpty) {
      LoggingService.instance.info('No favorite IDs provided, returning empty');
      return const <MediaEntity>[];
    }

    final storedMedia = await _mediaDataSource.getMedia();
    LoggingService.instance.info(
      'Found ${storedMedia.length} stored media items',
    );

    final storedMediaMap = {for (final media in storedMedia) media.id: media};
    final resolvedMedia = <MediaEntity>[];
    final missingIds = <String>[];

    for (final id in favoriteIds) {
      final stored = storedMediaMap[id];
      if (stored != null) {
        final entity = _mediaModelToEntity(stored);
        resolvedMedia.add(entity);
        LoggingService.instance.debug(
          'Successfully loaded cached media for ID $id: ${entity.name}, path: ${entity.path}',
        );
      } else {
        missingIds.add(id);
        LoggingService.instance.warning(
          'No cached media found for favorite ID $id, will attempt repository lookup',
        );
      }
    }

    if (missingIds.isNotEmpty) {
      LoggingService.instance.info(
        'Attempting to resolve ${missingIds.length} missing favorites via repository',
      );
      for (final id in missingIds) {
        final media = await _getMediaUseCase.byId(id);
        if (media != null) {
          resolvedMedia.add(media);
          LoggingService.instance.debug(
            'Resolved missing favorite $id via repository lookup',
          );
        } else {
          LoggingService.instance.warning(
            'Repository could not resolve favorite ID $id',
          );
        }
      }
    }

    LoggingService.instance.info(
      'Loaded ${resolvedMedia.length} valid media entities out of ${favoriteIds.length} favorites',
    );
    return resolvedMedia;
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
          ref.watch(directoryRepositoryProvider),
          ref.watch(isarMediaDataSourceProvider),
          ref.watch(getMediaUseCaseProvider),
          ref.watch(recursiveDirectoryActionsProvider),
        );
        viewModel.loadFavorites();
        return viewModel;
      },
    );
