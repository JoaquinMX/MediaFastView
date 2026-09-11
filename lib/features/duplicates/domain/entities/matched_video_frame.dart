import 'video_frame_presentation_time.dart';

/// The representative frame that produced a video's best lookup score.
class MatchedVideoFrame {
  const MatchedVideoFrame({
    required this.positionPercent,
    required this.timestamp,
    this.presentationTime,
  });

  /// Requested position in the video, as a whole percentage.
  final int positionPercent;

  /// Actual frame time returned by the native video decoder.
  final Duration timestamp;

  /// The exact AVFoundation time, when the native matcher supplied it.
  final VideoFramePresentationTime? presentationTime;
}
