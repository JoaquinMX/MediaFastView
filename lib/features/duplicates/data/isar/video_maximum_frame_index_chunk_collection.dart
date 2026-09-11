import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/entities/video_maximum_frame_index_chunk.dart';
import 'maximum_video_frame_descriptor_codec.dart';

part 'video_maximum_frame_index_chunk_collection.g.dart';

Id videoMaximumFrameIndexChunkCollectionId(String mediaId, int chunkIndex) {
  return isarIdFromKey('maximum_video_frame_chunk::$mediaId::$chunkIndex');
}

/// One bounded, serialized chunk of maximum-precision frame descriptors.
@collection
class VideoMaximumFrameIndexChunkCollection {
  VideoMaximumFrameIndexChunkCollection({
    required this.mediaId,
    required this.chunkIndex,
    required this.fingerprint,
    required this.descriptorBytes,
    required this.computedAt,
    this.encodedByteCount,
  });

  Id get id => videoMaximumFrameIndexChunkCollectionId(mediaId, chunkIndex);
  set id(Id value) {}

  @Index(composite: [CompositeIndex('chunkIndex')])
  String mediaId;
  int chunkIndex;
  String fingerprint;
  List<byte> descriptorBytes;
  DateTime computedAt;

  /// Null only on legacy rows awaiting the resumable metadata backfill.
  @Index()
  int? encodedByteCount;
}

extension VideoMaximumFrameIndexChunkCollectionMapper
    on VideoMaximumFrameIndexChunkCollection {
  VideoMaximumFrameIndexChunk toDomain() {
    return VideoMaximumFrameIndexChunk(
      mediaId: mediaId,
      chunkIndex: chunkIndex,
      fingerprint: fingerprint,
      descriptors: const MaximumVideoFrameDescriptorCodec().decode(
        mediaId: mediaId,
        bytes: descriptorBytes,
      ),
      computedAt: computedAt,
    );
  }
}

extension VideoMaximumFrameIndexChunkIsarMapper on VideoMaximumFrameIndexChunk {
  VideoMaximumFrameIndexChunkCollection toCollection() {
    final bytes = const MaximumVideoFrameDescriptorCodec().encode(descriptors);
    return VideoMaximumFrameIndexChunkCollection(
      mediaId: mediaId,
      chunkIndex: chunkIndex,
      fingerprint: fingerprint,
      descriptorBytes: bytes,
      computedAt: computedAt,
      encodedByteCount: bytes.length,
    );
  }
}
