/// Representative video positions used by frame-to-video lookup.
const List<int> videoFrameSamplePercents = <int>[10, 30, 50, 70, 90];

/// Versioned fingerprint for the five-frame lookup recipe.
String videoFrameLookupFingerprint({
  required int size,
  required DateTime lastModified,
}) {
  return 'video_frame_lookup_v1_${size}_'
      '${lastModified.millisecondsSinceEpoch}';
}

/// A perceptual hash for one representative frame of an indexed video.
class VideoFrameHash {
  const VideoFrameHash({
    required this.mediaId,
    required this.positionPercent,
    required this.timestamp,
    required this.hash,
    required this.width,
    required this.height,
    required this.fingerprint,
  });

  final String mediaId;
  final int positionPercent;
  final Duration timestamp;
  final int hash;
  final int width;
  final int height;
  final String fingerprint;
}
