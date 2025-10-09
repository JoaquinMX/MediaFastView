import '../../../../core/services/logging_service.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../data_sources/isar_media_data_source.dart';
import '../models/media_model.dart';

/// Implementation of MediaRepository using SharedPreferences.
class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl(this._mediaDataSource);

  final IsarMediaDataSource _mediaDataSource;

  @override
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId) async {
    final models = await _mediaDataSource.getMediaForDirectory(directoryId);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    final models = await _mediaDataSource.getMediaForDirectory(directoryId);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<MediaEntity?> getMediaById(String id) async {
    final allMedia = await _mediaDataSource.getMedia();
    final model = allMedia.where((media) => media.id == id).firstOrNull;
    if (model != null) {
      LoggingService.instance.debug('Found media for ID $id: ${model.name}');
    } else {
      LoggingService.instance.warning('No media found for ID $id among ${allMedia.length} items');
    }
    return model != null ? _modelToEntity(model) : null;
  }

  @override
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      final allMedia = await _mediaDataSource.getMedia();
      return allMedia.map(_modelToEntity).toList();
    }

    final allMedia = await _mediaDataSource.getMedia();
    final filtered = allMedia
        .where((media) => media.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();
    return filtered.map(_modelToEntity).toList();
  }

  @override
  Future<List<MediaEntity>> filterMediaByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    final allMedia = await _mediaDataSource.getMediaForDirectory(directoryId);

    if (tagIds.isEmpty) {
      return allMedia.map(_modelToEntity).toList();
    }

    final filtered = allMedia
        .where((media) => media.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();
    return filtered.map(_modelToEntity).toList();
  }

  @override
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    await _mediaDataSource.updateMediaTags(mediaId, tagIds);
  }

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _mediaDataSource.removeMediaForDirectory(directoryId);
  }

  /// Converts MediaModel to MediaEntity.
  MediaEntity _modelToEntity(MediaModel model) {
    return MediaEntity(
      id: model.id,
      path: model.path,
      name: model.name,
      type: model.type,
      size: model.size,
      lastModified: model.lastModified,
      tagIds: model.tagIds,
      directoryId: model.directoryId,
      bookmarkData: model.bookmarkData,
      thumbnailPath: model.thumbnailPath,
      width: model.width,
      height: model.height,
      duration: model.durationSeconds == null
          ? null
          : Duration(milliseconds: (model.durationSeconds! * 1000).round()),
      metadata: model.metadata,
    );
  }

}
