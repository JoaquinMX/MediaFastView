import 'maximum_video_frame_descriptor.dart';

/// A bounded batch of descriptors for a single video.
class VideoMaximumFrameIndexChunk {
  const VideoMaximumFrameIndexChunk({
    required this.mediaId,
    required this.chunkIndex,
    required this.fingerprint,
    required this.descriptors,
    required this.computedAt,
  });

  final String mediaId;
  final int chunkIndex;
  final String fingerprint;
  final List<MaximumVideoFrameDescriptor> descriptors;
  final DateTime computedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mediaId': mediaId,
    'chunkIndex': chunkIndex,
    'fingerprint': fingerprint,
    'computedAt': computedAt.toIso8601String(),
    'descriptors': descriptors
        .map((descriptor) => descriptor.toJson())
        .toList(growable: false),
  };

  factory VideoMaximumFrameIndexChunk.fromJson(Map<String, dynamic> json) {
    return VideoMaximumFrameIndexChunk(
      mediaId: json['mediaId'] as String,
      chunkIndex: json['chunkIndex'] as int,
      fingerprint: json['fingerprint'] as String,
      computedAt: DateTime.parse(json['computedAt'] as String),
      descriptors: (json['descriptors'] as List<dynamic>)
          .map(
            (value) => MaximumVideoFrameDescriptor.fromJson(
              Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            ),
          )
          .toList(growable: false),
    );
  }
}

typedef MaximumVideoFrameIndexChunk = VideoMaximumFrameIndexChunk;
