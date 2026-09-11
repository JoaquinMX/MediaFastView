import '../../../../core/models/video_frame_lookup_precision.dart';

/// Coverage of a video frame index for the active profile.
class VideoFrameIndexCoverage {
  const VideoFrameIndexCoverage({
    required this.totalVideos,
    required this.readyVideos,
    this.precision = VideoFrameLookupPrecision.standard,
    this.indexedFrameCount = 0,
    this.cacheSizeBytes = 0,
  });

  final int totalVideos;
  final int readyVideos;
  final VideoFrameLookupPrecision precision;
  final int indexedFrameCount;
  final int cacheSizeBytes;

  int get pendingVideos => totalVideos - readyVideos;

  bool get isComplete => pendingVideos == 0;

  bool get hasPartialCoverage => readyVideos > 0 && !isComplete;
}
