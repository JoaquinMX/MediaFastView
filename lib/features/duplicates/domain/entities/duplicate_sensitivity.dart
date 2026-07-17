/// How aggressively the clusterer treats two images as "the same picture".
///
/// Each level maps to a Hamming-distance threshold on the 64-bit dHash: two
/// images are linked when their hashes differ by at most [threshold] bits.
/// Retuning this re-clusters the already-computed hashes, so it is cheap and
/// never triggers a rescan.
enum DuplicateSensitivity { strict, balanced, loose }

extension DuplicateSensitivityX on DuplicateSensitivity {
  /// Maximum Hamming distance (out of 64 bits) still considered a match.
  int get threshold => switch (this) {
    DuplicateSensitivity.strict => 4,
    DuplicateSensitivity.balanced => 8,
    DuplicateSensitivity.loose => 12,
  };

  String get label => switch (this) {
    DuplicateSensitivity.strict => 'Strict',
    DuplicateSensitivity.balanced => 'Balanced',
    DuplicateSensitivity.loose => 'Loose',
  };

  String get helperText => switch (this) {
    DuplicateSensitivity.strict =>
      'Only near-identical copies. Fewest false positives.',
    DuplicateSensitivity.balanced =>
      'Catches resizes and re-encodes. A sensible default.',
    DuplicateSensitivity.loose =>
      'Also groups lightly edited or cropped shots. More to review.',
  };
}
