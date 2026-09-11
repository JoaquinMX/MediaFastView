/// Counts and status for the verification portion of an image lookup.
///
/// The summary is intentionally independent of the UI sensitivity. It records
/// the work performed so that a partial result remains honest when it is
/// displayed or restored from history.
final class ImageLookupVerificationSummary {
  const ImageLookupVerificationSummary({
    this.eligibleVideoCount = 0,
    this.verifiedVideoCount = 0,
    this.failedVideoCount = 0,
    this.invalidIndexVideoCount = 0,
    this.stopped = false,
    this.candidatePolicyVersion = 1,
  });

  final int eligibleVideoCount;
  final int verifiedVideoCount;
  final int failedVideoCount;
  final int invalidIndexVideoCount;
  final bool stopped;
  final int candidatePolicyVersion;

  ImageLookupVerificationSummary copyWith({
    int? eligibleVideoCount,
    int? verifiedVideoCount,
    int? failedVideoCount,
    int? invalidIndexVideoCount,
    bool? stopped,
    int? candidatePolicyVersion,
  }) {
    return ImageLookupVerificationSummary(
      eligibleVideoCount: eligibleVideoCount ?? this.eligibleVideoCount,
      verifiedVideoCount: verifiedVideoCount ?? this.verifiedVideoCount,
      failedVideoCount: failedVideoCount ?? this.failedVideoCount,
      invalidIndexVideoCount:
          invalidIndexVideoCount ?? this.invalidIndexVideoCount,
      stopped: stopped ?? this.stopped,
      candidatePolicyVersion:
          candidatePolicyVersion ?? this.candidatePolicyVersion,
    );
  }
}
