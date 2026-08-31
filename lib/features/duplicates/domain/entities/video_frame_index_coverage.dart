/// Coverage of the five-frame video index for the active profile.
class VideoFrameIndexCoverage {
  const VideoFrameIndexCoverage({
    required this.totalVideos,
    required this.readyVideos,
  });

  final int totalVideos;
  final int readyVideos;

  int get pendingVideos => totalVideos - readyVideos;

  bool get isComplete => pendingVideos == 0;
}
