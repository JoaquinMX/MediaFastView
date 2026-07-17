/// Progress of the perceptual-hashing pass over the library.
///
/// Hashing decodes every image through the platform engine, so on a large
/// library it takes real time — the UI drives a determinate bar off this and
/// offers a cancel. Reused hashes (unchanged files) are counted separately so
/// an incremental rescan can show how little work it actually did.
class DuplicateScanProgress {
  const DuplicateScanProgress({
    required this.processed,
    required this.total,
    this.reused = 0,
    this.failed = 0,
    this.isComplete = false,
    this.isCancelled = false,
  });

  const DuplicateScanProgress.initial()
    : processed = 0,
      total = 0,
      reused = 0,
      failed = 0,
      isComplete = false,
      isCancelled = false;

  /// Images hashed or reused so far.
  final int processed;

  /// Total images to process.
  final int total;

  /// How many of [processed] came from the cache rather than a fresh decode.
  final int reused;

  /// Images that could not be decoded (unsupported/corrupt) and were skipped.
  final int failed;

  final bool isComplete;
  final bool isCancelled;

  double get fraction {
    if (total <= 0) return 1;
    return (processed / total).clamp(0, 1).toDouble();
  }

  DuplicateScanProgress copyWith({
    int? processed,
    int? total,
    int? reused,
    int? failed,
    bool? isComplete,
    bool? isCancelled,
  }) {
    return DuplicateScanProgress(
      processed: processed ?? this.processed,
      total: total ?? this.total,
      reused: reused ?? this.reused,
      failed: failed ?? this.failed,
      isComplete: isComplete ?? this.isComplete,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

/// A cooperative cancel signal for a running scan. The hashing loop checks
/// [isCancelled] between images and stops early when it is set.
class DuplicateScanCancellation {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}
