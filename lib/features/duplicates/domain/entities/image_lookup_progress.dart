/// Stage of an active media lookup.
enum ImageLookupVerificationPhase { initial, remaining }

/// Stage of an active media lookup.
enum ImageLookupProgressStage {
  preparingQueries,
  preparingDescriptors,
  searchingIndexedMedia,
  scanningVideoFrames,
  verifyingVideoFrames,
}

/// Stage-aware progress for query preparation and indexed-media matching.
final class ImageLookupProgress {
  const ImageLookupProgress({
    required this.stage,
    required this.processed,
    required this.total,
    this.currentItemProcessed = 0,
    this.currentItemTotal = 0,
    this.verificationPhase,
  });

  const ImageLookupProgress.preparingQueries({
    required int processed,
    required int total,
  }) : this(
         stage: ImageLookupProgressStage.preparingQueries,
         processed: processed,
         total: total,
       );

  final ImageLookupProgressStage stage;

  /// Completed top-level items for the current [stage].
  final int processed;

  /// Total top-level items for the current [stage].
  final int total;

  /// Completed work inside the item currently being processed.
  final int currentItemProcessed;

  /// Total work inside the item currently being processed, when known.
  final int currentItemTotal;

  /// Distinguishes the first ranked sixteen videos from the automatic
  /// remaining-video pass without expanding [ImageLookupProgressStage].
  final ImageLookupVerificationPhase? verificationPhase;

  double get fraction {
    if (total <= 0) {
      return 0;
    }
    return (processed / total).clamp(0, 1).toDouble();
  }
}
