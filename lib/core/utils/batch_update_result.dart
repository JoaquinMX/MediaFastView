import 'package:collection/collection.dart';

/// Describes the outcome of a batch update operation, including the
/// identifiers that were successfully updated and any failures.
class BatchUpdateResult {
  const BatchUpdateResult({
    this.successfulIds = const <String>[],
    this.failureReasons = const <String, String>{},
  });

  /// Identifiers that were updated successfully.
  final List<String> successfulIds;

  /// Mapping of identifiers that failed to update to the associated reason.
  final Map<String, String> failureReasons;

  /// Indicates whether any updates failed.
  bool get hasFailures => failureReasons.isNotEmpty;

  /// Indicates whether any updates succeeded.
  bool get hasSuccesses => successfulIds.isNotEmpty;

  /// Creates an empty result representing a no-op operation.
  static const BatchUpdateResult empty = BatchUpdateResult();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BatchUpdateResult) return false;
    final listEquals = const ListEquality<String>().equals;
    final mapEquals = const MapEquality<String, String>().equals;
    return listEquals(successfulIds, other.successfulIds) &&
        mapEquals(failureReasons, other.failureReasons);
  }

  @override
  int get hashCode => Object.hash(
        const ListEquality<String>().hash(successfulIds),
        const MapEquality<String, String>().hash(failureReasons),
      );

  @override
  String toString() =>
      'BatchUpdateResult(successfulIds: $successfulIds, failureReasons: $failureReasons)';
}
