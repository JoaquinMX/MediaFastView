import 'duplicate_candidate.dart';
import 'keeper_strategy.dart';
import 'perceptual_hash.dart';

/// A cluster of visually similar images the user reviews as a unit: one keeper
/// plus the copies proposed for the Trash.
///
/// Immutable — changing the keeper or rebuilding under a new strategy returns a
/// fresh group. A group is only meaningful with two or more candidates; the
/// clusterer never emits singletons.
class DuplicateGroup {
  DuplicateGroup({required this.candidates, required this.keeperId})
    : assert(candidates.length >= 2, 'A duplicate group needs 2+ candidates');

  final List<DuplicateCandidate> candidates;

  /// The id of the copy to keep. Guaranteed to be one of [candidates].
  final String keeperId;

  DuplicateCandidate get keeper =>
      candidates.firstWhere((candidate) => candidate.id == keeperId);

  /// Every copy except the keeper — the ones eligible for deletion.
  List<DuplicateCandidate> get removable =>
      candidates.where((candidate) => candidate.id != keeperId).toList();

  /// Bytes freed if every non-keeper copy is trashed.
  int get reclaimableBytes =>
      removable.fold(0, (sum, candidate) => sum + candidate.sizeBytes);

  int get copyCount => candidates.length;

  int hashDistanceToKeeper(DuplicateCandidate candidate) =>
      hammingDistance(candidate.hash, keeper.hash);

  /// A stable identity for the group's membership, independent of order or which
  /// copy is currently the keeper. Used to remember a "not duplicates"
  /// dismissal and to key the group in lists. Regenerating it after members
  /// change means a dismissal only sticks while the same set of files clusters
  /// together.
  String get signature {
    final ids = candidates.map((candidate) => candidate.id).toList()..sort();
    return ids.join('|');
  }

  /// Same members, a different keeper. Ignores an id that is not in the group.
  DuplicateGroup withKeeper(String id) {
    if (id == keeperId || candidates.every((candidate) => candidate.id != id)) {
      return this;
    }
    return DuplicateGroup(candidates: candidates, keeperId: id);
  }

  /// Same members, keeper re-picked under [strategy].
  DuplicateGroup withStrategy(KeeperStrategy strategy) {
    return DuplicateGroup(
      candidates: candidates,
      keeperId: strategy.selectKeeperId(candidates),
    );
  }

  /// Drops [removedIds] from the group. Returns null when fewer than two copies
  /// survive (a group of one is no longer a duplicate). If the keeper itself was
  /// removed, the strategy re-picks one from the survivors.
  DuplicateGroup? withoutIds(Set<String> removedIds, KeeperStrategy strategy) {
    final survivors = candidates
        .where((candidate) => !removedIds.contains(candidate.id))
        .toList(growable: false);
    if (survivors.length < 2) {
      return null;
    }
    final keeperSurvived = survivors.any((c) => c.id == keeperId);
    return DuplicateGroup(
      candidates: survivors,
      keeperId: keeperSurvived ? keeperId : strategy.selectKeeperId(survivors),
    );
  }

  /// Builds a group from clustered [candidates], choosing the keeper by
  /// [strategy].
  factory DuplicateGroup.fromCandidates(
    List<DuplicateCandidate> candidates,
    KeeperStrategy strategy,
  ) {
    return DuplicateGroup(
      candidates: candidates,
      keeperId: strategy.selectKeeperId(candidates),
    );
  }
}
