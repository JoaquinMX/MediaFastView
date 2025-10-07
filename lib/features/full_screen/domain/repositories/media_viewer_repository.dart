import '../../../media_library/domain/entities/media_entity.dart';

/// Repository for full-screen media viewing operations
abstract class MediaViewerRepository {
  /// Load media list for a specific directory
  Future<List<MediaEntity>> loadMediaForDirectory(String directoryId);

  /// Get media by ID
  Future<MediaEntity?> getMediaById(String mediaId);

  /// Navigate to next media in the list
  Future<MediaEntity?> getNextMedia(
    String currentMediaId,
    List<String> mediaIds,
  );

  /// Navigate to previous media in the list
  Future<MediaEntity?> getPreviousMedia(
    String currentMediaId,
    List<String> mediaIds,
  );
}
