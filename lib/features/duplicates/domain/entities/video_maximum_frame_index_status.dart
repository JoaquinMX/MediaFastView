/// Completion state for a video's maximum-precision frame index.
enum MaximumVideoFrameIndexState { building, complete }

/// Fingerprint and completion marker for one maximum-precision video index.
class VideoMaximumFrameIndexStatus {
  const VideoMaximumFrameIndexStatus({
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

  final String mediaId;
  final String fingerprint;
  final int sourceSize;
  final DateTime sourceLastModified;
  final int descriptorVersion;
  final int visionRevision;
  final int frameCount;
  final int chunkCount;
  final MaximumVideoFrameIndexState state;
  final DateTime computedAt;

  bool get isComplete => state == MaximumVideoFrameIndexState.complete;

  VideoMaximumFrameIndexStatus copyWith({
    String? fingerprint,
    int? frameCount,
    int? chunkCount,
    MaximumVideoFrameIndexState? state,
  }) {
    return VideoMaximumFrameIndexStatus(
      mediaId: mediaId,
      fingerprint: fingerprint ?? this.fingerprint,
      sourceSize: sourceSize,
      sourceLastModified: sourceLastModified,
      descriptorVersion: descriptorVersion,
      visionRevision: visionRevision,
      frameCount: frameCount ?? this.frameCount,
      chunkCount: chunkCount ?? this.chunkCount,
      state: state ?? this.state,
      computedAt: computedAt,
    );
  }
}

/// Fixed revision used to keep persisted Vision scores reproducible.
const int maximumVideoFrameVisionRevision = 1;

/// Version of the compact descriptor recipe stored in the index fingerprint.
const int maximumVideoFrameDescriptorVersion = 2;

String maximumVideoFrameLookupFingerprint({
  required int size,
  required DateTime lastModified,
  int descriptorVersion = maximumVideoFrameDescriptorVersion,
  int visionRevision = maximumVideoFrameVisionRevision,
}) {
  return 'maximum_video_frame_lookup_v$descriptorVersion'
      '_vision${visionRevision}_${size}_'
      '${lastModified.millisecondsSinceEpoch}';
}
