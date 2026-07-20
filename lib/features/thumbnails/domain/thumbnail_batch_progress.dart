enum ThumbnailBatchStatus {
  idle,
  running,
  cancelling,
  completed,
  cancelled,
  failed,
}

/// Immutable progress and summary for a library thumbnail generation run.
class ThumbnailBatchProgress {
  const ThumbnailBatchProgress({
    required this.status,
    required this.total,
    required this.completed,
    required this.generated,
    required this.cacheHits,
    required this.failed,
    this.currentName,
    this.errorMessage,
  });

  const ThumbnailBatchProgress.idle()
    : status = ThumbnailBatchStatus.idle,
      total = 0,
      completed = 0,
      generated = 0,
      cacheHits = 0,
      failed = 0,
      currentName = null,
      errorMessage = null;

  final ThumbnailBatchStatus status;
  final int total;
  final int completed;
  final int generated;
  final int cacheHits;
  final int failed;
  final String? currentName;
  final String? errorMessage;

  bool get isActive =>
      status == ThumbnailBatchStatus.running ||
      status == ThumbnailBatchStatus.cancelling;

  double? get fraction => total > 0 ? completed / total : null;

  ThumbnailBatchProgress copyWith({
    ThumbnailBatchStatus? status,
    int? total,
    int? completed,
    int? generated,
    int? cacheHits,
    int? failed,
    String? currentName,
    bool clearCurrentName = false,
    String? errorMessage,
  }) {
    return ThumbnailBatchProgress(
      status: status ?? this.status,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      generated: generated ?? this.generated,
      cacheHits: cacheHits ?? this.cacheHits,
      failed: failed ?? this.failed,
      currentName: clearCurrentName ? null : currentName ?? this.currentName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
