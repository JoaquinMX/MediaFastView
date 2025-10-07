import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';

/// Use case for filtering directories and media by tags.
/// Provides unified filtering logic for both directories and media items.
class FilterByTagsUseCase {
  const FilterByTagsUseCase({
    required this.directoryRepository,
    required this.mediaRepository,
  });

  final DirectoryRepository directoryRepository;
  final MediaRepository mediaRepository;

  /// Filters directories by the given tag IDs.
  Future<List<DirectoryEntity>> filterDirectories(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return directoryRepository.getDirectories();
    }
    return directoryRepository.filterDirectoriesByTags(tagIds);
  }

  /// Filters media by the given tag IDs.
  Future<List<MediaEntity>> filterMedia(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      // If no tags selected, return all media (this would need to be implemented differently)
      // For now, return empty list as this use case is for filtering
      return [];
    }
    return mediaRepository.filterMediaByTags(tagIds);
  }

  /// Filters media within a specific directory by tag IDs.
  Future<List<MediaEntity>> filterMediaInDirectory(
    DirectoryEntity directory,
    List<String> tagIds,
  ) async {
    List<MediaEntity> filtered = const [];
    try {
      filtered = await mediaRepository.filterMediaByTagsForDirectory(
        tagIds,
        directory.path,
        bookmarkData: directory.bookmarkData,
      );
    } catch (_) {
      filtered = const [];
    }

    if (filtered.isNotEmpty || tagIds.isEmpty) {
      return filtered;
    }

    final cachedMedia = await mediaRepository.getMediaForDirectory(directory.id);
    if (tagIds.isEmpty) {
      return cachedMedia;
    }

    final tagIdSet = tagIds.toSet();
    return cachedMedia
        .where((media) => media.tagIds.any(tagIdSet.contains))
        .toList();
  }

  /// Gets combined results for directories and media filtered by tags.
  Future<FilteredResults> getFilteredResults(List<String> tagIds) async {
    final directories = await filterDirectories(tagIds);
    final media = await filterMedia(tagIds);

    return FilteredResults(directories: directories, media: media);
  }
}

/// Result class containing filtered directories and media.
class FilteredResults {
  const FilteredResults({required this.directories, required this.media});

  final List<DirectoryEntity> directories;
  final List<MediaEntity> media;

  bool get isEmpty => directories.isEmpty && media.isEmpty;
  int get totalCount => directories.length + media.length;
}
