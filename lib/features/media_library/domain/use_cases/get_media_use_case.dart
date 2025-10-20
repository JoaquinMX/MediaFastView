import '../entities/media_entity.dart';
import '../repositories/media_repository.dart';

/// Use case that retrieves media from the library through the repository
/// abstraction. It provides helpers for loading media scoped to a specific
/// directory as well as retrieving the entire media library.
class GetMediaUseCase {
  const GetMediaUseCase(this._mediaRepository);

  final MediaRepository _mediaRepository;

  /// Loads media for the directory located at [directoryPath].
  Future<List<MediaEntity>> forDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) {
    return _mediaRepository.getMediaForDirectoryPath(
      directoryPath,
      bookmarkData: bookmarkData,
    );
  }

  /// Loads media for the directory identified by [directoryId].
  Future<List<MediaEntity>> forDirectoryId(String directoryId) {
    return _mediaRepository.getMediaForDirectory(directoryId);
  }

  /// Loads media for the entire library.
  Future<List<MediaEntity>> entireLibrary() {
    return _mediaRepository.filterMediaByTags(const <String>[]);
  }

  /// Loads a single media entity by [id] if available.
  Future<MediaEntity?> byId(String id) {
    return _mediaRepository.getMediaById(id);
  }

  /// Filters media by [tagIds] for the directory at [directoryPath].
  Future<List<MediaEntity>> filterByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  }) {
    return _mediaRepository.filterMediaByTagsForDirectory(
      tagIds,
      directoryPath,
      bookmarkData: bookmarkData,
    );
  }
}
