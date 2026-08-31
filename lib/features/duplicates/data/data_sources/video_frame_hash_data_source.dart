import 'package:isar/isar.dart';

import '../../../../core/services/isar_database.dart';
import '../../domain/entities/video_frame_hash.dart';
import '../isar/video_frame_hash_collection.dart';

abstract interface class VideoFrameHashDataSource {
  Future<Map<String, List<VideoFrameHash>>> getByMediaIds(
    Iterable<String> mediaIds,
  );

  /// Atomically replaces the complete sample set for each supplied media id.
  Future<void> replaceAll(Map<String, List<VideoFrameHash>> hashesByMediaId);
}

class IsarVideoFrameHashDataSource implements VideoFrameHashDataSource {
  IsarVideoFrameHashDataSource(this._database);

  final IsarDatabase _database;

  Isar get _isar => _database.instance;

  IsarCollection<VideoFrameHashCollection> get _collection =>
      _isar.collection<VideoFrameHashCollection>();

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  @override
  Future<Map<String, List<VideoFrameHash>>> getByMediaIds(
    Iterable<String> mediaIds,
  ) async {
    await _ensureReady();
    final ids = <Id>[
      for (final mediaId in mediaIds)
        for (final positionPercent in videoFrameSamplePercents)
          videoFrameHashCollectionId(mediaId, positionPercent),
    ];
    if (ids.isEmpty) {
      return const <String, List<VideoFrameHash>>{};
    }
    final rows = await _collection.getAll(ids);
    final result = <String, List<VideoFrameHash>>{};
    for (final row in rows) {
      if (row != null) {
        result
            .putIfAbsent(row.mediaId, () => <VideoFrameHash>[])
            .add(row.toDomain());
      }
    }
    for (final hashes in result.values) {
      hashes.sort(
        (first, second) =>
            first.positionPercent.compareTo(second.positionPercent),
      );
    }
    return result;
  }

  @override
  Future<void> replaceAll(
    Map<String, List<VideoFrameHash>> hashesByMediaId,
  ) async {
    if (hashesByMediaId.isEmpty) {
      return;
    }
    await _ensureReady();
    final ids = <Id>[
      for (final mediaId in hashesByMediaId.keys)
        for (final positionPercent in videoFrameSamplePercents)
          videoFrameHashCollectionId(mediaId, positionPercent),
    ];
    final rows = hashesByMediaId.values
        .expand((hashes) => hashes)
        .map((hash) => hash.toCollection())
        .toList(growable: false);
    await _isar.writeTxn(() async {
      await _collection.deleteAll(ids);
      await _collection.putAll(rows);
    });
  }
}
