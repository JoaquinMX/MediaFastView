/// Controls how image-to-video frame lookup builds and searches its index.
enum VideoFrameLookupPrecision { standard, maximum }

extension VideoFrameLookupPrecisionX on VideoFrameLookupPrecision {
  /// Human-readable name shown beside the lookup scope.
  String get label => switch (this) {
    VideoFrameLookupPrecision.standard => 'Standard',
    VideoFrameLookupPrecision.maximum => 'Maximum precision',
  };

  /// Short description suitable for settings and lookup-option dialogs.
  String get description => switch (this) {
    VideoFrameLookupPrecision.standard =>
      'Searches five representative frames from each video.',
    VideoFrameLookupPrecision.maximum =>
      'Searches every decoded presentation frame. It takes longer and uses '
          'additional cache space.',
  };

  /// Maximum coarse dHash distance used to shortlist a candidate.
  ///
  /// These thresholds only control how many frames reach Vision verification;
  /// they are deliberately generous because a compact hash is never allowed
  /// to reject the best verified candidate by itself.
  int coarseThresholdFor(String sensitivity) => switch (sensitivity) {
    'strict' => 12,
    'balanced' => 20,
    'loose' => 28,
    _ => 20,
  };
}
