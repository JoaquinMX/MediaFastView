import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../../core/database/models/media_record.dart';
import '../../domain/entities/media_entity.dart';
import '../models/media_model.dart';

/// Data source for media persistence backed by Isar.
class IsarMediaDataSource {
  const IsarMediaDataSource(this._isar);

  final Isar _isar;

  Future<List<MediaModel>> getMedia() async {
    final records = await _isar.mediaRecords.where().findAll();
    return records.map(_mapFromRecord).toList();
  }

  Future<List<MediaModel>> getMediaForDirectory(String directoryId) async {
    final records = await _isar.mediaRecords
        .where()
        .directoryIdEqualTo(directoryId)
        .findAll();
    return records.map(_mapFromRecord).toList();
  }

  Future<void> upsertMedia(List<MediaModel> media) async {
    if (media.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      await _isar.mediaRecords.putAll(media.map(_mapToRecord).toList());
    });
  }

  Future<void> removeMediaForDirectory(String directoryId) async {
    await _isar.writeTxn(() async {
      final ids = await _isar.mediaRecords
          .where()
          .directoryIdEqualTo(directoryId)
          .isarIds();
      await _isar.mediaRecords.deleteAll(ids);
    });
  }

  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    await _isar.writeTxn(() async {
      final record = await _isar.mediaRecords
          .where()
          .filter()
          .idEqualTo(mediaId)
          .findFirst();
      if (record != null) {
        record.tagIds = List<String>.from(tagIds);
        await _isar.mediaRecords.put(record);
      }
    });
  }

  Future<void> deleteByMediaIds(Iterable<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      final ids = await _isar.mediaRecords
          .where()
          .filter()
          .anyOf(mediaIds, (q, mediaId) => q.idEqualTo(mediaId))
          .isarIds();
      await _isar.mediaRecords.deleteAll(ids);
    });
  }

  MediaModel _mapFromRecord(MediaRecord record) {
    return MediaModel(
      id: record.id,
      path: record.path,
      name: record.name,
      type: MediaType.values[record.type],
      size: record.size,
      lastModified: record.lastModified,
      tagIds: List<String>.from(record.tagIds),
      directoryId: record.directoryId,
      bookmarkData: record.bookmarkData,
      thumbnailPath: record.thumbnailPath,
      width: record.width,
      height: record.height,
      durationSeconds: record.durationSeconds,
      metadata: record.metadataJson == null
          ? null
          : (jsonDecode(record.metadataJson!) as Map<String, dynamic>),
    );
  }

  MediaRecord _mapToRecord(MediaModel model) {
    return MediaRecord(
      id: model.id,
      path: model.path,
      name: model.name,
      type: model.type.index,
      size: model.size,
      lastModified: model.lastModified,
      tagIds: List<String>.from(model.tagIds),
      directoryId: model.directoryId,
      bookmarkData: model.bookmarkData,
      thumbnailPath: model.thumbnailPath,
      width: model.width,
      height: model.height,
      durationSeconds: model.durationSeconds,
      metadataJson: model.metadata == null ? null : jsonEncode(model.metadata),
    )
      ..isarId = Isar.fastHash(model.id);
  }
}
