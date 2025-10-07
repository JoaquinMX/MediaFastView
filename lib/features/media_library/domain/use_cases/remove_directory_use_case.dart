import 'package:media_fast_view/core/services/logging_service.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import '../repositories/directory_repository.dart';
import '../repositories/media_repository.dart';

/// Use case for removing a directory.
/// Handles cascading deletion of associated media from favorites and tags.
class RemoveDirectoryUseCase {
  const RemoveDirectoryUseCase(
    this._directoryRepository,
    this._mediaRepository,
    this._favoritesRepository,
  );

  final DirectoryRepository _directoryRepository;
  final MediaRepository _mediaRepository;
  final FavoritesRepository _favoritesRepository;

  /// Executes the use case to remove a directory by ID.
  /// Cascades deletion by removing associated media from favorites and clearing tags.
  Future<void> call(String id) async {
    try {
      // Get the directory entity to access path and bookmark data
      final directory = await _directoryRepository.getDirectoryById(id);
      if (directory == null) {
        LoggingService.instance.warning('Directory with ID $id not found, skipping removal');
        return;
      }

      LoggingService.instance.info('Starting cascading removal for directory: ${directory.path}');

      // Get all media in the directory
      List mediaList = [];
      try {
        mediaList = await _mediaRepository.getMediaForDirectoryPath(
          directory.path,
          bookmarkData: directory.bookmarkData,
        );
        LoggingService.instance.debug('Found ${mediaList.length} media items in directory');
      } catch (e) {
        if (e.toString().contains('bookmark') || e.toString().contains('Bookmark')) {
          LoggingService.instance.warning('Failed to access directory media due to invalid bookmark, skipping cleanup for directory: ${directory.path}');
          mediaList = []; // Skip cleanup
        } else {
          rethrow;
        }
      }

      // Remove each media from favorites and clear tags
      for (final media in mediaList) {
        try {
          // Check if favorited and remove if so
          final isFavorite = await _favoritesRepository.isFavorite(media.id);
          if (isFavorite) {
            await _favoritesRepository.removeFavorite(media.id);
            LoggingService.instance.debug('Removed media ${media.id} from favorites');
          }

          // Clear all tags from the media
          if (media.tagIds.isNotEmpty) {
            await _mediaRepository.updateMediaTags(media.id, []);
            LoggingService.instance.debug('Cleared tags for media ${media.id}');
          }
        } catch (e) {
          LoggingService.instance.error('Failed to clean up media ${media.id}: $e');
          // Continue with other media items
        }
      }

      // Finally, remove the directory itself
      await _directoryRepository.removeDirectory(id);
      LoggingService.instance.info('Successfully removed directory: ${directory.path}');
    } catch (e) {
      LoggingService.instance.error('Failed to remove directory $id: $e');
      rethrow;
    }
  }
}
