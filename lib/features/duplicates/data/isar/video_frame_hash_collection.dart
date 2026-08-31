import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/entities/video_frame_hash.dart';

part 'video_frame_hash_collection.g.dart';

Id videoFrameHashCollectionId(String mediaId, int positionPercent) {
  return isarIdFromKey('$mediaId:$positionPercent');
}

/// Cached perceptual hash for one sampled frame of a video.
@collection
class VideoFrameHashCollection {
  VideoFrameHashCollection({
    required this.mediaId,
    required this.positionPercent,
    required this.timestampMilliseconds,
    required this.hash,
    required this.width,
    required this.height,
    required this.fingerprint,
    required this.computedAt,
  });

  Id get id => videoFrameHashCollectionId(mediaId, positionPercent);
  set id(Id value) {}

  String mediaId;
  int positionPercent;
  int timestampMilliseconds;
  int hash;
  int width;
  int height;
  String fingerprint;
  DateTime computedAt;
}

extension VideoFrameHashCollectionMapper on VideoFrameHashCollection {
  VideoFrameHash toDomain() {
    return VideoFrameHash(
      mediaId: mediaId,
      positionPercent: positionPercent,
      timestamp: Duration(milliseconds: timestampMilliseconds),
      hash: hash,
      width: width,
      height: height,
      fingerprint: fingerprint,
    );
  }
}

extension VideoFrameHashIsarMapper on VideoFrameHash {
  VideoFrameHashCollection toCollection({DateTime? computedAt}) {
    return VideoFrameHashCollection(
      mediaId: mediaId,
      positionPercent: positionPercent,
      timestampMilliseconds: timestamp.inMilliseconds,
      hash: hash,
      width: width,
      height: height,
      fingerprint: fingerprint,
      computedAt: computedAt ?? DateTime.now(),
    );
  }
}
