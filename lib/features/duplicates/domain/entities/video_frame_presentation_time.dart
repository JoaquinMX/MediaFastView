/// The exact rational presentation timestamp supplied by AVFoundation.
///
/// [duration] is a compatibility view for Flutter UI and history. Matching
/// and seeking keep [value] and [timescale] so millisecond rounding never
/// changes the frame that is verified.
class VideoFramePresentationTime {
  const VideoFramePresentationTime({
    required this.value,
    required this.timescale,
  });

  final int value;
  final int timescale;

  /// Returns whether two CMTime pairs represent the same rational instant.
  ///
  /// AVFoundation can return an equivalent timestamp with a different
  /// timescale than the one emitted by the track reader, so matching must not
  /// fall back to rounded milliseconds in that case.
  bool isEquivalentTo(VideoFramePresentationTime other) {
    return value * other.timescale == other.value * timescale;
  }

  Duration get duration {
    if (timescale == 0) {
      return Duration.zero;
    }
    return Duration(
      microseconds: (value * Duration.microsecondsPerSecond / timescale)
          .round(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VideoFramePresentationTime &&
        value == other.value &&
        timescale == other.timescale;
  }

  @override
  int get hashCode => Object.hash(value, timescale);
}
