import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/entities/video_maximum_frame_index_status.dart';

part 'video_maximum_frame_index_status_collection.g.dart';

Id videoMaximumFrameIndexStatusCollectionId(String mediaId) {
  return isarIdFromKey('maximum_video_frame_status::$mediaId');
}

/// Completion marker for a maximum-precision frame index.
@collection
class VideoMaximumFrameIndexStatusCollection {
  VideoMaximumFrameIndexStatusCollection({
    required this.mediaId,
    required this.fingerprint,
    required this.sourceSize,
    required this.sourceLastModified,
    required this.descriptorVersion,
    required this.visionRevision,
    required this.frameCount,
    required this.chunkCount,
    required this.state,
    required this.computedAt,
  });

  Id get id => videoMaximumFrameIndexStatusCollectionId(mediaId);
  set id(Id value) {}

  @Index(unique: true, replace: true)
  String mediaId;
  String fingerprint;
  int sourceSize;
  DateTime sourceLastModified;
  int descriptorVersion;
  int visionRevision;
  int frameCount;
  int chunkCount;
  String state;
  DateTime computedAt;
}

extension VideoMaximumFrameIndexStatusCollectionMapper
    on VideoMaximumFrameIndexStatusCollection {
  VideoMaximumFrameIndexStatus toDomain() {
    return VideoMaximumFrameIndexStatus(
      mediaId: mediaId,
      fingerprint: fingerprint,
      sourceSize: sourceSize,
      sourceLastModified: sourceLastModified,
      descriptorVersion: descriptorVersion,
      visionRevision: visionRevision,
      frameCount: frameCount,
      chunkCount: chunkCount,
      state: MaximumVideoFrameIndexState.values.firstWhere(
        (value) => value.name == state,
        orElse: () => MaximumVideoFrameIndexState.building,
      ),
      computedAt: computedAt,
    );
  }
}

extension VideoMaximumFrameIndexStatusIsarMapper
    on VideoMaximumFrameIndexStatus {
  VideoMaximumFrameIndexStatusCollection toCollection() {
    return VideoMaximumFrameIndexStatusCollection(
      mediaId: mediaId,
      fingerprint: fingerprint,
      sourceSize: sourceSize,
      sourceLastModified: sourceLastModified,
      descriptorVersion: descriptorVersion,
      visionRevision: visionRevision,
      frameCount: frameCount,
      chunkCount: chunkCount,
      state: state.name,
      computedAt: computedAt,
    );
  }
}
