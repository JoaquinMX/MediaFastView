import '../../../../core/services/logging_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../data_sources/local_media_data_source.dart';
import '../isar/isar_media_data_source.dart';
import '../persistence/hybrid_persistence_bridge.dart';
import '../models/media_model.dart';

/// Implementation of MediaRepository using SharedPreferences.
class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(
    IsarMediaDataSource isarMediaDataSource,
    SharedPreferencesMediaDataSource legacyMediaDataSource,
  ) : _mediaPersistence = MediaPersistenceBridge(
          isarMediaDataSource: isarMediaDataSource,
          legacyMediaDataSource: legacyMediaDataSource,
        );

  final MediaPersistenceBridge _mediaPersistence;

  @override
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId) async {
    final models = await _mediaPersistence.loadMediaForDirectory(directoryId);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = generateDirectoryId(directoryPath);
    final models = await _mediaPersistence.loadMediaForDirectory(directoryId);
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<MediaEntity?> getMediaById(String id) async {
    final allMedia = await _mediaPersistence.loadAllMedia();
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
      final allMedia = await _mediaPersistence.loadAllMedia();
      return allMedia.map(_modelToEntity).toList();
    }

    final allMedia = await _mediaPersistence.loadAllMedia();
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
    final allMedia = await _mediaPersistence.loadMediaForDirectory(directoryId);

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
    await _mediaPersistence.updateMediaTags(mediaId, tagIds);
  }

  @override
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  ) async {
    if (mediaTags.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final models = await _mediaPersistence.loadAllMedia();
    final indexById = {
      for (var i = 0; i < models.length; i++) models[i].id: i,
    };

    final successes = <String>[];
    final failures = <String, String>{};

    for (final entry in mediaTags.entries) {
      final index = indexById[entry.key];
      if (index == null) {
        failures[entry.key] = 'Media not found';
        continue;
      }

      models[index] = models[index].copyWith(tagIds: entry.value);
      successes.add(entry.key);
    }

    if (successes.isNotEmpty) {
      await _mediaPersistence.saveMedia(models);
      LoggingService.instance.info(
        'Updated tags for ${successes.length} media items in a single batch.',
      );
    }

    if (failures.isNotEmpty) {
      LoggingService.instance.warning(
        'Failed to update tags for media: ${failures.keys.join(', ')}',
      );
    }

    return BatchUpdateResult(
      successfulIds: successes,
      failureReasons: failures,
    );
  }

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _mediaPersistence.removeMediaForDirectory(directoryId);
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
    );
  }

}
