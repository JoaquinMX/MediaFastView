/// The representative frame that produced a video's best lookup score.
class MatchedVideoFrame {
  const MatchedVideoFrame({
    required this.positionPercent,
    required this.timestamp,
  });

  /// Requested position in the video, as a whole percentage.
  final int positionPercent;

  /// Actual frame time returned by the native video decoder.
  final Duration timestamp;
}
