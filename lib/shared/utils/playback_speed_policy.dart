/// Called when a playback speed cannot be applied by the media backend.
typedef PlaybackSpeedRejectedCallback =
    void Function(double attemptedSpeed, double fallbackSpeed);

/// Defines the playback-speed values supported by the viewer controls.
abstract final class PlaybackSpeedPolicy {
  static const double minimum = 0.5;
  static const double maximum = 16.0;
  static const double step = 0.5;
  static const int sliderDivisions = 31;
  static const List<double> presets = <double>[1.0, 2.0, 3.0];

  /// Clamps [speed] to the supported range and snaps it to the nearest step.
  ///
  /// Returns `null` when [speed] is not finite.
  static double? normalize(double speed) {
    if (!speed.isFinite) {
      return null;
    }

    final clampedSpeed = speed.clamp(minimum, maximum).toDouble();
    final stepCount = ((clampedSpeed - minimum) / step).round();
    return minimum + (stepCount * step);
  }

  /// Formats [speed] without an unnecessary decimal for whole-number values.
  static String format(double speed) {
    return speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toStringAsFixed(1);
  }
}
