import '../entities/duplicate_group.dart';
import '../entities/duplicate_scan_progress.dart';
import '../entities/duplicate_sensitivity.dart';
import '../entities/keeper_strategy.dart';

/// Finds and manages visually-similar image groups within the active profile's
/// library.
///
/// The two halves are deliberately split: [hashLibrary] is the expensive,
/// cancellable pass that decodes images and caches their perceptual hashes;
/// [loadGroups] is the cheap clustering step that runs off those cached hashes,
/// so retuning sensitivity never rescans.
abstract class DuplicateRepository {
  /// Hashes every image in the library, reusing cached hashes for files whose
  /// size and mtime are unchanged. Emits progress; the terminal event has
  /// `isComplete` or `isCancelled` set.
  Stream<DuplicateScanProgress> hashLibrary({
    DuplicateScanCancellation? cancellation,
  });

  /// Clusters the cached hashes into duplicate groups at [sensitivity], choosing
  /// each group's keeper by [keeperStrategy] and dropping dismissed groups.
  /// Sorted by reclaimable bytes, largest first. Images without a cached hash
  /// (never scanned, or undecodable) are excluded.
  Future<List<DuplicateGroup>> loadGroups({
    required DuplicateSensitivity sensitivity,
    required KeeperStrategy keeperStrategy,
  });

  /// Remembers that the group with [signature] is not a real duplicate set, so
  /// it is filtered out of future [loadGroups] results until its membership
  /// changes.
  Future<void> dismissGroup(String signature);
}
