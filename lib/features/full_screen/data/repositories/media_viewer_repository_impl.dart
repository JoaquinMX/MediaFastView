import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../domain/repositories/media_viewer_repository.dart';
import '../../../../core/services/logging_service.dart';

/// Implementation of MediaViewerRepository
class MediaViewerRepositoryImpl implements MediaViewerRepository {
  const MediaViewerRepositoryImpl(this._mediaRepository);

  final MediaRepository _mediaRepository;

  @override
  Future<List<MediaEntity>> loadMediaForDirectory(String directoryId) async {
    LoggingService.instance.debug('loadMediaForDirectory called with directoryId: $directoryId');
    final result = await _mediaRepository.getMediaForDirectory(directoryId);
    LoggingService.instance.info('getMediaForDirectory returned ${result.length} items');
    return result;
  }

  @override
  Future<MediaEntity?> getMediaById(String mediaId) async {
    return _mediaRepository.getMediaById(mediaId);
  }

  @override
  Future<MediaEntity?> getNextMedia(
    String currentMediaId,
    List<String> mediaIds,
  ) async {
    final currentIndex = mediaIds.indexOf(currentMediaId);
    if (currentIndex == -1 || currentIndex == mediaIds.length - 1) {
      return null;
    }
    final nextMediaId = mediaIds[currentIndex + 1];
    return getMediaById(nextMediaId);
  }

  @override
  Future<MediaEntity?> getPreviousMedia(
    String currentMediaId,
    List<String> mediaIds,
  ) async {
    final currentIndex = mediaIds.indexOf(currentMediaId);
    if (currentIndex == -1 || currentIndex == 0) {
      return null;
    }
    final previousMediaId = mediaIds[currentIndex - 1];
    return getMediaById(previousMediaId);
  }
}
