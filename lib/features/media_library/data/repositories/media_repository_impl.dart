import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../core/services/logging_service.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/media_repository.dart';
import '../data_sources/local_media_data_source.dart';
import '../models/media_model.dart';

/// Implementation of MediaRepository using SharedPreferences.
class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl(this._mediaDataSource);

  final SharedPreferencesMediaDataSource _mediaDataSource;

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
    final directoryId = _generateDirectoryId(directoryPath);
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
    final directoryId = _generateDirectoryId(directoryPath);
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

  /// Generates directory ID from path (consistent with other parts of the app)
  String _generateDirectoryId(String directoryPath) {
    final bytes = utf8.encode(directoryPath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
