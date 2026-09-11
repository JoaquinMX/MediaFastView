import 'package:isar/isar.dart';

import '../../../../core/services/isar_database.dart';
import '../../domain/entities/video_maximum_frame_index_chunk.dart';
import '../../domain/entities/video_maximum_frame_index_status.dart';
import '../isar/video_maximum_frame_index_chunk_collection.dart';
import '../isar/video_maximum_frame_index_status_collection.dart';

/// Persistence boundary for the optional every-frame video index.
abstract interface class VideoMaximumFrameIndexDataSource {
  Future<Map<String, VideoMaximumFrameIndexStatus>> getStatuses(
    Iterable<String> mediaIds,
  );

  /// Streams persisted chunks in bounded pages without loading an entire
  /// video's index into memory.
  Stream<VideoMaximumFrameIndexChunk> streamChunks(String mediaId);

  /// Removes any old status/chunks before a new index is built.
  Future<void> begin(VideoMaximumFrameIndexStatus status);

  /// Persists one bounded chunk. The completion marker is written separately.
  Future<void> putChunk(VideoMaximumFrameIndexChunk chunk);

  /// Writes the complete marker only after all chunks have been persisted.
  Future<void> complete(VideoMaximumFrameIndexStatus status);

  /// Removes a possibly incomplete index and all its chunks.
  Future<void> delete(String mediaId);

  /// Removes every maximum-precision status and chunk.
  Future<void> clear();

  /// Approximate encoded cache size in bytes.
  Future<int> getCacheSize();
}

/// Serialized chunk exposed by packed-index implementations.
///
/// The lookup scanner can validate and consume records directly from
/// [descriptorBytes] without allocating a descriptor list for every chunk.
final class VideoMaximumFrameIndexEncodedChunk {
  const VideoMaximumFrameIndexEncodedChunk({
    required this.mediaId,
    required this.chunkIndex,
    required this.fingerprint,
    required this.descriptorBytes,
    required this.computedAt,
  });

  final String mediaId;
  final int chunkIndex;
  final String fingerprint;
  final List<int> descriptorBytes;
  final DateTime computedAt;
}

/// Optional packed scan implemented by the Isar data source.
abstract interface class PackedVideoMaximumFrameIndexDataSource {
  Stream<VideoMaximumFrameIndexEncodedChunk> streamEncodedChunks(
    String mediaId,
  );
}

/// Optional coordination hook used to prevent a clear operation from being
/// followed by stale writes from an already-running native index pass.
abstract interface class GenerationAwareVideoMaximumFrameIndexDataSource {
  int get generation;

  Future<bool> beginIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int generation,
  );

  Future<bool> putChunkIfCurrent(
    VideoMaximumFrameIndexChunk chunk,
    int generation,
  );

  Future<bool> completeIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int generation,
  );
}

/// Optional integrity check used when reporting coverage from persisted data.
abstract interface class MaximumVideoFrameIndexIntegrityDataSource {
  Future<bool> hasCompleteChunks(VideoMaximumFrameIndexStatus status);
}

/// Isar-backed incremental maximum-index storage.
class IsarVideoMaximumFrameIndexDataSource
    implements
        VideoMaximumFrameIndexDataSource,
        GenerationAwareVideoMaximumFrameIndexDataSource,
        MaximumVideoFrameIndexIntegrityDataSource,
        PackedVideoMaximumFrameIndexDataSource {
  IsarVideoMaximumFrameIndexDataSource(this._database);

  final IsarDatabase _database;
  int _generation = 0;
  final Set<String> _buildingMediaIds = <String>{};
  Future<void>? _metadataBackfill;

  @override
  int get generation => _generation;

  Isar get _isar => _database.instance;

  IsarCollection<VideoMaximumFrameIndexStatusCollection> get _statuses =>
      _isar.collection<VideoMaximumFrameIndexStatusCollection>();

  IsarCollection<VideoMaximumFrameIndexChunkCollection> get _chunks =>
      _isar.collection<VideoMaximumFrameIndexChunkCollection>();

  Future<void> _ensureReady() async {
    if (!_database.isOpen) {
      await _database.open();
    }
  }

  @override
  Future<Map<String, VideoMaximumFrameIndexStatus>> getStatuses(
    Iterable<String> mediaIds,
  ) async {
    await _ensureReady();
    final ids = mediaIds
        .map(videoMaximumFrameIndexStatusCollectionId)
        .toList(growable: false);
    if (ids.isEmpty) {
      return const <String, VideoMaximumFrameIndexStatus>{};
    }
    final result = <String, VideoMaximumFrameIndexStatus>{};
    for (final row in await _statuses.getAll(ids)) {
      if (row != null) {
        result[row.mediaId] = row.toDomain();
      }
    }
    return result;
  }

  @override
  Future<bool> hasCompleteChunks(VideoMaximumFrameIndexStatus status) async {
    var chunkCount = 0;
    var frameCount = 0;
    var expectedFrameIndex = 0;
    await for (final chunk in streamChunks(status.mediaId)) {
      if (chunk.chunkIndex != chunkCount ||
          chunk.fingerprint != status.fingerprint) {
        return false;
      }
      for (final descriptor in chunk.descriptors) {
        if (descriptor.mediaId != status.mediaId ||
            descriptor.frameIndex != expectedFrameIndex) {
          return false;
        }
        expectedFrameIndex++;
      }
      chunkCount++;
      frameCount += chunk.descriptors.length;
    }
    return chunkCount == status.chunkCount && frameCount == status.frameCount;
  }

  @override
  Stream<VideoMaximumFrameIndexChunk> streamChunks(String mediaId) async* {
    await _ensureReady();
    const pageSize = 16;
    var lastChunkIndex = -1;
    while (true) {
      final rows = await _chunks
          .where()
          .mediaIdEqualToChunkIndexGreaterThan(mediaId, lastChunkIndex)
          .limit(pageSize)
          .findAll();
      for (final row in rows) {
        yield row.toDomain();
      }
      await Future<void>.delayed(Duration.zero);
      if (rows.length < pageSize) {
        break;
      }
      lastChunkIndex = rows.last.chunkIndex;
    }
  }

  @override
  Stream<VideoMaximumFrameIndexEncodedChunk> streamEncodedChunks(
    String mediaId,
  ) async* {
    await _ensureReady();
    const pageSize = 16;
    var lastChunkIndex = -1;
    while (true) {
      final rows = await _chunks
          .where()
          .mediaIdEqualToChunkIndexGreaterThan(mediaId, lastChunkIndex)
          .limit(pageSize)
          .findAll();
      for (final row in rows) {
        yield VideoMaximumFrameIndexEncodedChunk(
          mediaId: row.mediaId,
          chunkIndex: row.chunkIndex,
          fingerprint: row.fingerprint,
          descriptorBytes: row.descriptorBytes,
          computedAt: row.computedAt,
        );
      }
      await Future<void>.delayed(Duration.zero);
      if (rows.length < pageSize) {
        break;
      }
      lastChunkIndex = rows.last.chunkIndex;
    }
  }

  @override
  Future<void> begin(VideoMaximumFrameIndexStatus status) async {
    await beginIfCurrent(status, _generation);
  }

  @override
  Future<bool> beginIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int generation,
  ) async {
    await _ensureReady();
    if (_generation != generation) {
      return false;
    }
    var didWrite = false;
    await _isar.writeTxn(() async {
      if (_generation != generation) {
        return;
      }
      await _deleteInTxn(status.mediaId);
      await _statuses.put(status.toCollection());
      _buildingMediaIds.add(status.mediaId);
      didWrite = true;
    });
    return didWrite;
  }

  @override
  Future<void> putChunk(VideoMaximumFrameIndexChunk chunk) async {
    final didWrite = await putChunkIfCurrent(chunk, _generation);
    if (!didWrite) {
      throw StateError(
        'Maximum-precision index is no longer being built for ${chunk.mediaId}',
      );
    }
  }

  @override
  Future<bool> putChunkIfCurrent(
    VideoMaximumFrameIndexChunk chunk,
    int generation,
  ) async {
    await _ensureReady();
    if (_generation != generation ||
        !_buildingMediaIds.contains(chunk.mediaId)) {
      return false;
    }
    var didWrite = false;
    await _isar.writeTxn(() async {
      if (_generation != generation ||
          !_buildingMediaIds.contains(chunk.mediaId)) {
        return;
      }
      await _chunks.put(chunk.toCollection());
      didWrite = true;
    });
    return didWrite;
  }

  @override
  Future<void> complete(VideoMaximumFrameIndexStatus status) async {
    final didWrite = await completeIfCurrent(status, _generation);
    if (!didWrite) {
      throw StateError(
        'Maximum-precision index is no longer being built for ${status.mediaId}',
      );
    }
  }

  @override
  Future<bool> completeIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int generation,
  ) async {
    await _ensureReady();
    if (_generation != generation ||
        !_buildingMediaIds.contains(status.mediaId)) {
      return false;
    }
    var chunkCount = 0;
    var frameCount = 0;
    var expectedFrameIndex = 0;
    await for (final chunk in streamChunks(status.mediaId)) {
      if (_generation != generation ||
          chunk.chunkIndex != chunkCount ||
          chunk.fingerprint != status.fingerprint) {
        return false;
      }
      for (final descriptor in chunk.descriptors) {
        if (descriptor.mediaId != status.mediaId ||
            descriptor.frameIndex != expectedFrameIndex) {
          return false;
        }
        expectedFrameIndex++;
      }
      chunkCount++;
      frameCount += chunk.descriptors.length;
    }
    if (chunkCount != status.chunkCount || frameCount != status.frameCount) {
      return false;
    }
    var didWrite = false;
    await _isar.writeTxn(() async {
      if (_generation != generation ||
          !_buildingMediaIds.contains(status.mediaId)) {
        return;
      }
      await _statuses.put(status.toCollection());
      _buildingMediaIds.remove(status.mediaId);
      didWrite = true;
    });
    return didWrite;
  }

  @override
  Future<void> delete(String mediaId) async {
    await _ensureReady();
    await _isar.writeTxn(() async {
      await _deleteInTxn(mediaId);
    });
    _buildingMediaIds.remove(mediaId);
  }

  Future<void> _deleteInTxn(String mediaId) async {
    await _statuses.delete(videoMaximumFrameIndexStatusCollectionId(mediaId));
    await _chunks.where().mediaIdEqualToAnyChunkIndex(mediaId).deleteAll();
  }

  @override
  Future<void> clear() async {
    await _ensureReady();
    _generation++;
    _buildingMediaIds.clear();
    await _isar.writeTxn(() async {
      await _statuses.clear();
      await _chunks.clear();
    });
  }

  @override
  Future<int> getCacheSize() async {
    await _ensureReady();
    final backfill = _metadataBackfill ??= _backfillEncodedByteCounts();
    try {
      await backfill;
    } finally {
      if (identical(_metadataBackfill, backfill)) {
        _metadataBackfill = null;
      }
    }
    return _chunks.where().encodedByteCountProperty().sum();
  }

  /// Fills legacy metadata in small transactions. Re-querying missing rows
  /// inside each transaction cannot resurrect chunks deleted by cache clear or
  /// replace newer chunks written during preparation. Completed batches remain
  /// persisted if a later batch fails or the application exits.
  Future<void> _backfillEncodedByteCounts() async {
    const pageSize = 32;
    while (true) {
      final hasMissing = await _chunks
          .where()
          .encodedByteCountIsNull()
          .isNotEmpty();
      if (!hasMissing) {
        return;
      }
      await _isar.writeTxn(() async {
        final rows = await _chunks
            .where()
            .encodedByteCountIsNull()
            .limit(pageSize)
            .findAll();
        for (final row in rows) {
          row.encodedByteCount = row.descriptorBytes.length;
        }
        await _chunks.putAll(rows);
      });
      await Future<void>.delayed(Duration.zero);
    }
  }
}
