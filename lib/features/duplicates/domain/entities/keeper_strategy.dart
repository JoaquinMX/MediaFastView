import 'duplicate_candidate.dart';

/// The rule that picks which copy in a group is the suggested keeper. The
/// keeper is protected from deletion; every other copy is pre-selected for the
/// Trash. The user can always override per group.
enum KeeperStrategy { highestResolution, largestFile, newest }

extension KeeperStrategyX on KeeperStrategy {
  String get label => switch (this) {
    KeeperStrategy.highestResolution => 'Keep highest resolution',
    KeeperStrategy.largestFile => 'Keep largest file',
    KeeperStrategy.newest => 'Keep newest',
  };

  /// Chooses the keeper id from [candidates] under this strategy.
  ///
  /// Ties fall through a fixed chain so the choice is deterministic: resolution,
  /// then bytes, then most recently modified, then the shortest path (an
  /// original usually lives closer to a library root than an exported copy),
  /// then the id itself as a final tiebreak.
  String selectKeeperId(List<DuplicateCandidate> candidates) {
    assert(candidates.isNotEmpty, 'A group always has at least one candidate');
    final ranked = [...candidates]..sort((a, b) => _compare(b, a));
    return ranked.first.id;
  }

  int _compare(DuplicateCandidate a, DuplicateCandidate b) {
    // Returns a>b ordering value (higher == better keeper).
    int byResolution() => a.pixelCount.compareTo(b.pixelCount);
    int byBytes() => a.sizeBytes.compareTo(b.sizeBytes);
    int byNewest() => a.media.lastModified.compareTo(b.media.lastModified);

    final primary = switch (this) {
      KeeperStrategy.highestResolution => byResolution(),
      KeeperStrategy.largestFile => byBytes(),
      KeeperStrategy.newest => byNewest(),
    };
    if (primary != 0) return primary;

    // Shared tiebreak chain, best-quality-leaning, then deterministic.
    final resolution = byResolution();
    if (resolution != 0) return resolution;
    final bytes = byBytes();
    if (bytes != 0) return bytes;
    final newest = byNewest();
    if (newest != 0) return newest;
    final byShorterPath = b.media.path.length.compareTo(a.media.path.length);
    if (byShorterPath != 0) return byShorterPath;
    return a.id.compareTo(b.id);
  }
}
