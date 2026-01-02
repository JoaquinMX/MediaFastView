import '../../../../core/services/logging_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../isar/isar_media_data_source.dart';
import '../models/media_model.dart';

/// Implementation of MediaRepository backed by Isar persistence.
class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(
    this._mediaDataSource,
  );

  final IsarMediaDataSource _mediaDataSource;

  MediaModel _entityToModel(MediaEntity entity) {
    return MediaModel(
      id: entity.id,
      path: entity.path,
      name: entity.name,
      type: entity.type,
      size: entity.size,
      lastModified: entity.lastModified,
      tagIds: entity.tagIds,
      directoryId: entity.directoryId,
      bookmarkData: entity.bookmarkData,
    );
  }

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
  Future<List<MediaEntity>> getAllMedia() async {
    final models = await _mediaDataSource.getMedia();
    return models.map(_modelToEntity).toList();
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
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  ) async {
    return _mediaDataSource.updateMediaTagsBatch(mediaTags);
  }

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _mediaDataSource.removeMediaForDirectory(directoryId);
  }

  @override
  Future<void> removeMediaNotInDirectories(List<String> directoryIds) {
    return _mediaDataSource.removeMediaNotInDirectories(directoryIds);
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
    );
  }

  @override
  Future<void> clearAllMedia() {
    return _mediaDataSource.clearMedia();
  }

  @override
  Future<void> upsertMedia(List<MediaEntity> media) async {
    if (media.isEmpty) {
      return;
    }

    await _mediaDataSource.upsertMedia(
      media.map(_entityToModel).toList(growable: false),
    );
  }
}
